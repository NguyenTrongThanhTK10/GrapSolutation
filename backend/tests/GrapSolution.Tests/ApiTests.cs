using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
namespace GrapSolution.Tests;

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string databasePath = Path.Combine(Path.GetTempPath(), "grap-tests-" + Guid.NewGuid() + ".db");
    protected override void ConfigureWebHost(IWebHostBuilder builder) => builder.UseEnvironment("Development").UseSetting("ConnectionStrings:Sqlite", "Data Source=" + databasePath + ";Foreign Keys=True;Default Timeout=30").UseSetting("DataProtection:KeyPath", Path.Combine(Path.GetTempPath(), "grap-test-keys"));
    protected override void Dispose(bool disposing) { base.Dispose(disposing); if (File.Exists(databasePath)) File.Delete(databasePath); }
}
public sealed class ApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string user)
    {
        var client = factory.CreateClient(); var response = await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = user, deviceId = Guid.NewGuid().ToString() }); response.EnsureSuccessStatusCode(); var session = await response.Content.ReadFromJsonAsync<JsonElement>(); client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", session.GetProperty("accessToken").GetString()); return client;
    }
    private static async Task<JsonElement> Json(HttpResponseMessage response) { var body = await response.Content.ReadAsStringAsync(); Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode}: {body}"); return JsonDocument.Parse(body).RootElement.Clone(); }
    private static Task<HttpResponseMessage> Command(HttpClient client, string path, object body, string? key = null) { var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1" + path) { Content = JsonContent.Create(body) }; request.Headers.Add("Idempotency-Key", key ?? Guid.NewGuid().ToString()); return client.SendAsync(request); }
    private static async Task<JsonElement> Quote(HttpClient client) => await Json(await client.PostAsJsonAsync("/api/v1/quotes", new { pickup = new { latitude = 10.7721, longitude = 106.6983, address = "Chợ Bến Thành" }, dropoff = new { latitude = 10.7951, longitude = 106.7218, address = "Landmark 81" }, serviceTypeCode = "BIKE", paymentMethodType = "CASH" }));
    private async Task<string> PrepareOffer(HttpClient driver, HttpClient customer)
    {
        var availability = await Json(await driver.GetAsync("/api/v1/drivers/me/availability"));
        await Json(await driver.PostAsJsonAsync("/api/v1/drivers/me/availability", new { expectedVersion = availability.GetProperty("version").GetInt32(), online = true }));
        await Json(await driver.PostAsync("/api/v1/drivers/me/heartbeat", null));
        await Json(await driver.PostAsJsonAsync("/api/v1/drivers/me/location-batches", new { samples = new[] { new { latitude = 10.7721, longitude = 106.6983, accuracyMeters = 15, recordedAt = DateTime.UtcNow, sequence = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() } } }));
        var quote = await Quote(customer); await Json(await Command(customer, "/rides", new { quoteId = quote.GetProperty("quoteId").GetString() }));
        for (var i = 0; i < 30; i++) { var current = await Json(await driver.GetAsync("/api/v1/drivers/me/offers/current")); if (current.GetProperty("offer").ValueKind != JsonValueKind.Null) return current.GetProperty("offer").GetProperty("offerId").GetString()!; await Task.Delay(200); }
        throw new Exception("Dispatch did not create an offer.");
    }
    [Fact] public async Task Health_and_openapi_are_available() { var client = factory.CreateClient(); Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/ready")).StatusCode); Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/openapi/v1.json")).StatusCode); }
    [Fact] public async Task Customer_cannot_read_admin_or_another_customers_ride() { var customer = await Login("customer-7"); Assert.Equal(HttpStatusCode.Forbidden, (await customer.GetAsync("/api/v1/admin/drivers")).StatusCode); var other = await Login("customer-6"); var quote = await Quote(other); var ride = await Json(await Command(other, "/rides", new { quoteId = quote.GetProperty("quoteId").GetString() })); var id = ride.GetProperty("rideId").GetString(); Assert.Equal(HttpStatusCode.NotFound, (await customer.GetAsync("/api/v1/rides/" + id)).StatusCode); await Json(await Command(other, "/rides/" + id + "/cancel", new { expectedVersion = 1, reasonCode = "TEST_CLEANUP" })); }
    [Fact] public async Task Twenty_retries_create_one_ride_and_conflicting_payload_is_rejected()
    {
        var customer = await Login("customer-5"); var quote = await Quote(customer); var body = new { quoteId = quote.GetProperty("quoteId").GetString() }; var key = Guid.NewGuid().ToString(); var responses = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Command(customer, "/rides", body, key))); var ids = new List<string>(); foreach (var response in responses) ids.Add((await Json(response)).GetProperty("rideId").GetString()!); Assert.Single(ids.Distinct());
        Assert.Equal(HttpStatusCode.Conflict, (await Command(customer, "/rides", new { quoteId = "different" }, key)).StatusCode);
        var replay = await Json(await Command(customer, "/rides/" + ids[0] + "/cancel", new { expectedVersion = 1, reasonCode = "TEST_CANCEL" }, "same-cancel-key")); Assert.Equal(2, replay.GetProperty("version").GetInt32()); Assert.Equal(2, (await Json(await Command(customer, "/rides/" + ids[0] + "/cancel", new { expectedVersion = 1, reasonCode = "TEST_CANCEL" }, "same-cancel-key"))).GetProperty("version").GetInt32());
    }
    [Fact] public async Task Quote_owner_expiry_and_one_active_ride_are_enforced()
    {
        var customer = await Login("customer-4"); var other = await Login("customer-3"); var quote = await Quote(customer); Assert.Equal(HttpStatusCode.NotFound, (await Command(other, "/rides", new { quoteId = quote.GetProperty("quoteId").GetString() })).StatusCode);
        using(var scope = factory.Services.CreateScope()) { var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var q = await db.Set<Quote>().FindAsync(quote.GetProperty("quoteId").GetString()); q!.ExpiresAt = DateTime.UtcNow.AddSeconds(-1); await db.SaveChangesAsync(); }
        Assert.Equal(HttpStatusCode.Conflict, (await Command(customer, "/rides", new { quoteId = quote.GetProperty("quoteId").GetString() })).StatusCode);
        var q1 = await Quote(customer); var q2 = await Quote(customer); var results = await Task.WhenAll(Command(customer, "/rides", new { quoteId = q1.GetProperty("quoteId").GetString() }), Command(customer, "/rides", new { quoteId = q2.GetProperty("quoteId").GetString() })); Assert.Single(results, r => r.IsSuccessStatusCode); Assert.Single(results, r => r.StatusCode == HttpStatusCode.Conflict); var ride = await Json(results.Single(r => r.IsSuccessStatusCode)); await Json(await Command(customer, "/rides/" + ride.GetProperty("rideId").GetString() + "/cancel", new { expectedVersion = 1, reasonCode = "TEST_CLEANUP" }));
    }
    [Fact] public async Task Full_cash_lifecycle_is_balanced_and_retry_safe()
    {
        var driver = await Login("driver-user-0"); var customer = await Login("customer-0"); var offer = await PrepareOffer(driver, customer); var accepted = await Json(await Command(driver, "/driver-offers/" + offer + "/accept", new { expectedVersion = 1 })); Assert.Equal(JsonValueKind.Null, accepted.GetProperty("pickupPin").ValueKind); var id = accepted.GetProperty("rideId").GetString()!;
        Assert.Equal(HttpStatusCode.Conflict, (await Command(driver, "/driver-offers/" + offer + "/accept", new { expectedVersion = 1 })).StatusCode);
        var far = await Command(driver, "/rides/" + id + "/arrive", new { expectedVersion = 2, location = new { latitude = 10.8, longitude = 106.75, accuracyMeters = 10, recordedAt = DateTime.UtcNow } }); Assert.Equal(HttpStatusCode.UnprocessableEntity, far.StatusCode);
        await Json(await Command(driver, "/rides/" + id + "/arrive", new { expectedVersion = 2, location = new { latitude = 10.7721, longitude = 106.6983, accuracyMeters = 15, recordedAt = DateTime.UtcNow } }));
        var own = await Json(await customer.GetAsync("/api/v1/rides/" + id)); var pin = own.GetProperty("pickupPin").GetString();
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await Command(driver, "/rides/" + id + "/start", new { expectedVersion = 3, pickupPin = "wrong" })).StatusCode);
        using (var check = factory.Services.CreateScope()) { Assert.Equal(1, (await check.ServiceProvider.GetRequiredService<GrapDbContext>().Set<Ride>().FindAsync(id))!.PinAttempts); }
        await Json(await Command(driver, "/rides/" + id + "/start", new { expectedVersion = 3, pickupPin = pin })); Assert.Equal(HttpStatusCode.Conflict, (await Command(customer, "/rides/" + id + "/cancel", new { expectedVersion = 4, reasonCode = "ALREADY_STARTED" })).StatusCode);
        var oldGps = new { samples = new[] { new { latitude = 10.8, longitude = 106.75, accuracyMeters = 12, recordedAt = DateTime.UtcNow.AddSeconds(-10), sequence = 1, sampleId = "offline-old-sample" } } };
        await Json(await driver.PostAsJsonAsync("/api/v1/drivers/me/location-batches", oldGps));
        var duplicate = await Json(await driver.PostAsJsonAsync("/api/v1/drivers/me/location-batches", oldGps)); Assert.Equal(0, duplicate.GetProperty("accepted").GetInt32());
        var snapshot = await Json(await customer.GetAsync("/api/v1/rides/" + id)); Assert.Equal(10.7721, snapshot.GetProperty("driver").GetProperty("latitude").GetDouble());
        var share = await Json(await customer.PostAsync("/api/v1/rides/" + id + "/share-tokens", null));
        var completionBody = new { expectedVersion = 4, location = new { latitude = 10.7951, longitude = 106.7218, accuracyMeters = 10, recordedAt = DateTime.UtcNow } }; var completeKey = Guid.NewGuid().ToString(); var completed = await Json(await Command(driver, "/rides/" + id + "/complete", completionBody, completeKey)); await Json(await Command(driver, "/rides/" + id + "/complete", completionBody, completeKey));
        var payment = completed.GetProperty("payment"); Assert.Equal("PENDING", payment.GetProperty("status").GetString()); var paymentId = payment.GetProperty("id").GetString(); var amount = payment.GetProperty("payableAmount").GetInt64(); var cash = new { operationId = Guid.NewGuid().ToString(), collectedAmount = amount, currency = "VND", reasonCode = "FULL_AMOUNT_RECEIVED" }; var cashKey = Guid.NewGuid().ToString(); await Json(await Command(driver, "/payments/" + paymentId + "/cash-collections", cash, cashKey)); await Json(await Command(driver, "/payments/" + paymentId + "/cash-collections", cash, cashKey));
        Assert.Equal(JsonValueKind.Null, completed.GetProperty("driver").GetProperty("latitude").ValueKind);
        Assert.Equal(HttpStatusCode.Gone, (await factory.CreateClient().GetAsync("/api/v1/public/ride-shares/" + share.GetProperty("token").GetString())).StatusCode);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await Command(driver, "/payments/" + paymentId + "/cash-collections", new { operationId = Guid.NewGuid().ToString(), collectedAmount = 1, currency = "VND", reasonCode = "OVER_COLLECTION" })).StatusCode);
        using var scope = factory.Services.CreateScope(); var db2 = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var journals = await db2.Set<Journal>().Include(j => j.Entries).Where(j => j.RideId == id).ToListAsync(); Assert.Equal(2, journals.Count); Assert.All(journals, j => Assert.Equal(j.Entries.Sum(e => e.Debit), j.Entries.Sum(e => e.Credit))); Assert.Equal(1, await db2.Set<CashCollection>().CountAsync(c => c.PaymentId == paymentId)); Assert.False(await db2.Set<Assignment>().AnyAsync(a => a.RideId == id && a.EndedAt == null));
    }
    [Fact] public async Task Refresh_rotation_rejects_reuse_and_revokes_family()
    {
        var client = factory.CreateClient(); var login = await Json(await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = "customer-2" })); var old = login.GetProperty("refreshToken").GetString(); var fresh = await Json(await client.PostAsJsonAsync("/api/v1/auth/token/refresh", new { refreshToken = old })); Assert.Equal(HttpStatusCode.Unauthorized, (await client.PostAsJsonAsync("/api/v1/auth/token/refresh", new { refreshToken = old })).StatusCode); client.DefaultRequestHeaders.Authorization = new("Bearer", fresh.GetProperty("accessToken").GetString()); Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/me")).StatusCode);
    }
    [Fact] public async Task Private_upload_checks_magic_bytes_and_owner()
    {
        var driver = await Login("driver-user-9"); var other = await Login("customer-1");
        var bytes = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=");
        var intent = await Json(await driver.PostAsJsonAsync("/api/v1/files/upload-intents", new { contentType = "image/png", size = bytes.Length, purpose = "DRIVER_DOCUMENT" })); var id = intent.GetProperty("fileId").GetString();
        var forged = new ByteArrayContent(new byte[bytes.Length]); forged.Headers.ContentType = new MediaTypeHeaderValue("image/png"); Assert.Equal(HttpStatusCode.UnprocessableEntity, (await driver.PutAsync("/api/v1/files/" + id + "/content", forged)).StatusCode);
        var image = new ByteArrayContent(bytes); image.Headers.ContentType = new MediaTypeHeaderValue("image/png"); await Json(await driver.PutAsync("/api/v1/files/" + id + "/content", image)); await Json(await driver.PostAsync("/api/v1/files/" + id + "/complete", null));
        Assert.Equal(HttpStatusCode.OK, (await driver.GetAsync("/api/v1/files/" + id + "/content")).StatusCode); Assert.Equal(HttpStatusCode.Forbidden, (await other.GetAsync("/api/v1/files/" + id + "/content")).StatusCode);
    }
    [Fact] public async Task Remittance_maker_cannot_approve_and_approval_is_retry_safe()
    {
        var maker = await Login("staff-FinanceOperator"); var approver = await Login("staff-FinanceApprover");
        var request = await Json(await Command(maker, "/admin/cash-remittances", new { driverId = "driver-2", amount = 1000, reference = "TEST-" + Guid.NewGuid(), evidence = "Đã đối chiếu giao dịch ngân hàng thử nghiệm" })); var id = request.GetProperty("id").GetString();
        Assert.Equal(HttpStatusCode.Forbidden, (await Command(maker, "/admin/cash-remittances/" + id + "/approve", new { expectedVersion = 1 })).StatusCode);
        var key = Guid.NewGuid().ToString(); var approved = await Json(await Command(approver, "/admin/cash-remittances/" + id + "/approve", new { expectedVersion = 1 }, key)); Assert.Equal("APPROVED", approved.GetProperty("status").GetString()); await Json(await Command(approver, "/admin/cash-remittances/" + id + "/approve", new { expectedVersion = 1 }, key));
        using var scope = factory.Services.CreateScope(); Assert.Equal(1, await scope.ServiceProvider.GetRequiredService<GrapDbContext>().Set<Journal>().CountAsync(j => j.OperationKey == "remittance:" + id));
    }
}
