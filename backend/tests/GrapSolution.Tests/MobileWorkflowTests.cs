using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
namespace GrapSolution.Tests;

public sealed class MobileWorkflowTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private static readonly byte[] Image = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=");
    private async Task<HttpClient> Login(string id)
    {
        var client = factory.CreateClient(); var session = await Ok(await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = id, deviceId = Guid.NewGuid().ToString() }));
        client.DefaultRequestHeaders.Authorization = new("Bearer", session.GetProperty("accessToken").GetString()); return client;
    }
    private static async Task<JsonElement> Ok(HttpResponseMessage response) { var body = await response.Content.ReadAsStringAsync(); Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode}: {body}"); return JsonDocument.Parse(body).RootElement.Clone(); }
    private static Task<HttpResponseMessage> Post(HttpClient client, string route, object body) { var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1" + route) { Content = JsonContent.Create(body) }; request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString()); return client.SendAsync(request); }
    private static async Task<JsonElement> Upload(HttpClient client, string type)
    {
        var intent = await Ok(await client.PostAsJsonAsync("/api/v1/files/upload-intents", new { contentType = "image/png", size = Image.Length, purpose = "DRIVER_DOCUMENT" }));
        var id = intent.GetProperty("fileId").GetString(); var content = new ByteArrayContent(Image); content.Headers.ContentType = new MediaTypeHeaderValue("image/png"); await Ok(await client.PutAsync("/api/v1/files/" + id + "/content", content)); await Ok(await client.PostAsync("/api/v1/files/" + id + "/complete", null));
        return await Ok(await client.PostAsJsonAsync("/api/v1/drivers/me/documents", new { type, fileId = id, expiresAt = DateTime.UtcNow.AddYears(1) }));
    }
    [Fact] public async Task Applicant_can_submit_correct_rejected_document_and_get_reviewed_without_mutating_pending_profile()
    {
        string userId, driverId;
        using(var scope = factory.Services.CreateScope()) { var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var user = new User { Phone = "+848" + Random.Shared.NextInt64(10000000, 99999999), Name = "Tài xế mới kiểm thử", Role = Roles.Driver }; var driver = new Driver { UserId = user.Id }; db.Add(user); db.Add(driver); await db.SaveChangesAsync(); userId = user.Id; driverId = driver.Id; }
        var applicant = await Login(userId); var reviewer = await Login("staff-DriverReviewer");
        var saved = await Ok(await applicant.PutAsJsonAsync("/api/v1/drivers/me/application", new { expectedVersion = 1, serviceTypeCode = "BIKE", plate = "59-X1 12345", vehicle = "Honda Vision", color = "Trắng", approvalStatus = "APPROVED" })); Assert.Equal("DRAFT", saved.GetProperty("reviewStatus").GetString());
        foreach(var type in new[] { "IDENTITY", "DRIVING_LICENSE", "VEHICLE_REGISTRATION", "INSURANCE" }) await Upload(applicant, type);
        var application = await Ok(await applicant.GetAsync("/api/v1/drivers/me/application")); await Ok(await applicant.PostAsJsonAsync("/api/v1/drivers/me/application/submit", new { expectedVersion = application.GetProperty("version").GetInt32() }));
        application = await Ok(await applicant.GetAsync("/api/v1/drivers/me/application"));
        Assert.Equal(HttpStatusCode.Conflict, (await applicant.PutAsJsonAsync("/api/v1/drivers/me/application", new { expectedVersion = application.GetProperty("version").GetInt32(), serviceTypeCode = "CAR_4", plate = "CHANGE", vehicle = "Changed", color = "Đen" })).StatusCode);
        var documents = await Ok(await reviewer.GetAsync("/api/v1/admin/drivers/" + driverId + "/documents")); var identity = documents.GetProperty("items").EnumerateArray().Single(d => d.GetProperty("type").GetString() == "IDENTITY");
        await Ok(await reviewer.PostAsJsonAsync("/api/v1/admin/driver-documents/" + identity.GetProperty("id").GetString() + "/review-decisions", new { expectedVersion = 1, decision = "REJECTED", reasonCode = "Ảnh mờ, cần nộp lại" }));
        await Ok(await reviewer.PostAsJsonAsync("/api/v1/admin/drivers/" + driverId + "/review-decisions", new { expectedVersion = application.GetProperty("version").GetInt32(), decision = "REJECTED", reasonCode = "Cần bổ sung giấy tờ định danh" }));
        documents = await Ok(await applicant.GetAsync("/api/v1/drivers/me/documents")); Assert.Contains(documents.GetProperty("items").EnumerateArray(), d => d.GetProperty("reviewReason").GetString() == "Ảnh mờ, cần nộp lại");
        application = await Ok(await applicant.GetAsync("/api/v1/drivers/me/application")); Assert.Equal(HttpStatusCode.UnprocessableEntity, (await applicant.PostAsJsonAsync("/api/v1/drivers/me/application/submit", new { expectedVersion = application.GetProperty("version").GetInt32() })).StatusCode);
        await Upload(applicant, "IDENTITY"); application = await Ok(await applicant.GetAsync("/api/v1/drivers/me/application")); await Ok(await applicant.PostAsJsonAsync("/api/v1/drivers/me/application/submit", new { expectedVersion = application.GetProperty("version").GetInt32() }));
        documents = await Ok(await reviewer.GetAsync("/api/v1/admin/drivers/" + driverId + "/documents"));
        foreach(var document in documents.GetProperty("items").EnumerateArray().GroupBy(d => d.GetProperty("type").GetString()).Select(g => g.OrderByDescending(d => d.GetProperty("version").GetInt32()).First())) await Ok(await reviewer.PostAsJsonAsync("/api/v1/admin/driver-documents/" + document.GetProperty("id").GetString() + "/review-decisions", new { expectedVersion = document.GetProperty("version").GetInt32(), decision = "APPROVED", reasonCode = "Đã kiểm tra bản giấy tờ" }));
        application = await Ok(await applicant.GetAsync("/api/v1/drivers/me/application")); await Ok(await reviewer.PostAsJsonAsync("/api/v1/admin/drivers/" + driverId + "/review-decisions", new { expectedVersion = application.GetProperty("version").GetInt32(), decision = "APPROVED", reasonCode = "Hồ sơ đầy đủ và còn hạn" }));
        Assert.Equal("APPROVED", (await Ok(await applicant.GetAsync("/api/v1/drivers/me/availability"))).GetProperty("reviewStatus").GetString());
    }
    [Fact] public async Task No_show_requires_wait_time_and_a_contact_attempt_after_arrival()
    {
        string rideId;
        using(var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var secrets = scope.ServiceProvider.GetRequiredService<ISecrets>();
            var quote = new Quote { CustomerId = "customer-3", Pickup = DemoMapProvider.Places[0].Point, Dropoff = DemoMapProvider.Places[1].Point };
            var ride = new Ride { CustomerId = "customer-3", DriverId = "driver-0", QuoteId = quote.Id, Pickup = quote.Pickup, Dropoff = quote.Dropoff, Status = "DRIVER_ARRIVED", ArrivedAt = DateTime.UtcNow.AddMinutes(-6), Version = 3, CustomerPinProtected = secrets.Protect("1234"), PinHmac = secrets.Hmac("1234") };
            db.Add(quote); db.Add(ride); db.Add(new Assignment { DriverId = "driver-0", RideId = ride.Id }); await db.SaveChangesAsync(); rideId = ride.Id;
        }
        var driver = await Login("driver-user-0"); var customer = await Login("customer-3");
        var failed = await Post(driver, "/rides/" + rideId + "/no-show", new { expectedVersion = 3, reasonCode = "Không thấy khách" }); Assert.Equal(HttpStatusCode.UnprocessableEntity, failed.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await Post(customer, "/rides/" + rideId + "/contact-attempts", new { channel = "PHONE", note = "Không có quyền ghi nhận" })).StatusCode);
        await Ok(await Post(driver, "/rides/" + rideId + "/contact-attempts", new { channel = "PHONE", note = "Đã thử liên hệ qua kênh được cấp" }));
        var canceled = await Ok(await Post(driver, "/rides/" + rideId + "/no-show", new { expectedVersion = 3, reasonCode = "Khách không xuất hiện sau khi chờ và liên hệ" })); Assert.Equal("CANCELED", canceled.GetProperty("status").GetString());
        using var verification = factory.Services.CreateScope(); Assert.False(await verification.ServiceProvider.GetRequiredService<GrapDbContext>().Set<Assignment>().AnyAsync(a => a.RideId == rideId && a.EndedAt == null));
    }
    [Fact] public async Task Released_driver_cannot_recover_live_ride_data_through_history()
    {
        string rideId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var secrets = scope.ServiceProvider.GetRequiredService<ISecrets>();
            var quote = new Quote { CustomerId = "customer-4", Pickup = DemoMapProvider.Places[0].Point, Dropoff = DemoMapProvider.Places[1].Point };
            var ride = new Ride { CustomerId = "customer-4", DriverId = "driver-2", QuoteId = quote.Id, Pickup = quote.Pickup, Dropoff = quote.Dropoff, Status = "ASSIGNED", Version = 4, CustomerPinProtected = secrets.Protect("4321"), PinHmac = secrets.Hmac("4321") };
            db.Add(quote); db.Add(ride); db.Add(new Assignment { DriverId = "driver-1", RideId = ride.Id, EndedAt = DateTime.UtcNow.AddMinutes(-1), EndReason = "RELEASED" }); db.Add(new Assignment { DriverId = "driver-2", RideId = ride.Id }); await db.SaveChangesAsync(); rideId = ride.Id;
        }
        var oldDriver = await Login("driver-user-1"); var history = await Ok(await oldDriver.GetAsync("/api/v1/rides?pageSize=100"));
        Assert.DoesNotContain(history.GetProperty("items").EnumerateArray(), r => r.GetProperty("rideId").GetString() == rideId);
        Assert.Equal(HttpStatusCode.NotFound, (await oldDriver.GetAsync("/api/v1/rides/" + rideId)).StatusCode);
    }
}
