using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class BookingDiscoveryTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string id)
    {
        var c = factory.CreateClient();
        var response = await c.PostAsJsonAsync("/api/v1/auth/development", new { userId = id });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        c.DefaultRequestHeaders.Authorization = new("Bearer", json.GetProperty("accessToken").GetString());
        return c;
    }
    [Fact]
    public async Task Place_search_matches_vietnamese_without_accents_multiple_terms_and_airport_alias()
    {
        var c = await Login("customer-7");
        foreach (var q in new[] { "san bay tan son nhat", "TÂN SƠN NHẤT", "TSN", "SGN" })
        {
            var response = await c.GetAsync("/api/v1/places/autocomplete?q=" + Uri.EscapeDataString(q)); response.EnsureSuccessStatusCode();
            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("DEVELOPMENT_FIXTURE", json.GetProperty("source").GetString());
            Assert.Single(json.GetProperty("items").EnumerateArray());
            Assert.Equal("airport", json.GetProperty("items")[0].GetProperty("placeId").GetString());
        }
        Assert.Equal(HttpStatusCode.BadRequest, (await c.GetAsync("/api/v1/places/autocomplete?q=" + new string('a', 151))).StatusCode);
    }
    [Fact]
    public async Task Nearby_counts_only_eligible_unreserved_drivers_and_never_returns_their_identity_or_coordinates()
    {
        var c = await Login("customer-7");
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            var now = DateTime.UtcNow;
            Driver Add(string code = "BIKE")
            {
                var user = new User { Name = "Private Driver", Phone = Guid.NewGuid().ToString(), Role = Roles.Driver };
                var session = new Session { UserId = user.Id, RefreshHash = Guid.NewGuid().ToString() };
                var d = new Driver { UserId = user.Id, ServiceTypeCode = code, ReviewStatus = "APPROVED", Online = true,
                    ActiveSessionId = session.Id, DocumentsExpireAt = now.AddDays(10), HeartbeatAt = now, LocationAt = now,
                    Latitude = 10.7721, Longitude = 106.6983, Accuracy = 10 };
                db.Add(user); db.Add(session); db.Add(d); return d;
            }
            Add(); Add("CAR_7");
            Add().Online = false;
            Add().LocationAt = now.AddMinutes(-5);
            Add().HeartbeatAt = now.AddMinutes(-5);
            Add().DocumentsExpireAt = now.AddDays(-1);
            Add().ReviewStatus = "PENDING_REVIEW";
            Add().Accuracy = 500;
            Add().ActiveSessionId = null;
            Add().Latitude = 10.9;
            Add().ZoneId = "different-zone";
            var revoked = Add();
            db.Set<Session>().Local.Single(s => s.Id == revoked.ActiveSessionId).RevokedAt = now;
            var busy = Add(); var reserved = Add();
            var quote = new Quote { CustomerId = "customer-7" };
            var ride = new Ride { QuoteId = quote.Id, CustomerId = "customer-7", DriverId = busy.Id, Status = "IN_PROGRESS" };
            db.Add(quote); db.Add(ride);
            db.Add(new Assignment { DriverId = busy.Id, RideId = ride.Id });
            db.Add(new Offer { DriverId = reserved.Id, RideId = ride.Id, ExpiresAt = now.AddMinutes(2) });
            await db.SaveChangesAsync();
        }
        var response = await c.GetAsync("/api/v1/customers/me/nearby-services?latitude=10.7721&longitude=106.6983"); response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(json.GetProperty("inServiceZone").GetBoolean());
        Assert.Equal(3000, json.GetProperty("radiusMeters").GetInt32());
        var counts = json.GetProperty("items").EnumerateArray().ToDictionary(x => x.GetProperty("code").GetString()!, x => x.GetProperty("availableCount").GetInt32());
        Assert.Equal(1, counts["BIKE"]); Assert.Equal(0, counts["CAR_4"]); Assert.Equal(1, counts["CAR_7"]);
        foreach (var field in new[] { "driverId", "latitude", "longitude", "plate", "phone", "Private Driver" }) Assert.DoesNotContain(field, json.GetRawText());
    }
    [Fact]
    public async Task Nearby_requires_customer_role_and_valid_coordinate_and_handles_outside_service_area()
    {
        const string path = "/api/v1/customers/me/nearby-services";
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync(path + "?latitude=10&longitude=106")).StatusCode);
        var driver = await Login("driver-user-9");
        Assert.Equal(HttpStatusCode.Forbidden, (await driver.GetAsync(path + "?latitude=10&longitude=106")).StatusCode);
        var customer = await Login("customer-6");
        Assert.Equal(HttpStatusCode.BadRequest, (await customer.GetAsync(path + "?latitude=91&longitude=106")).StatusCode);
        var response = await customer.GetAsync(path + "?latitude=21.03&longitude=105.85"); response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(json.GetProperty("inServiceZone").GetBoolean());
        Assert.All(json.GetProperty("items").EnumerateArray(), item => Assert.Equal(0, item.GetProperty("availableCount").GetInt32()));
    }
}

public sealed class PlaceProviderTests
{
    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> response) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => Task.FromResult(response(request));
    }
    [Fact]
    public async Task Configured_autocomplete_uses_the_provider_and_preserves_safe_coordinates()
    {
        var map = new HttpMapProvider(new HttpClient(new Handler(request =>
        {
            Assert.Equal("/autocomplete", request.RequestUri!.AbsolutePath);
            Assert.Contains("Tân Sơn Nhất & ga", Uri.UnescapeDataString(request.RequestUri.Query));
            return new(HttpStatusCode.OK) { Content = new StringContent("{\"items\":[{\"placeId\":\"provider-place\",\"latitude\":10.8,\"longitude\":106.6,\"address\":\"Ga quốc nội\"}]}", Encoding.UTF8, "application/json") };
        })), "https://maps.invalid");
        var result = await map.Search("Tân Sơn Nhất & ga", default);
        Assert.Equal("provider-place", Assert.Single(result).PlaceId);
    }
    [Theory]
    [InlineData("{\"items\":[{\"placeId\":\"bad\",\"latitude\":91,\"longitude\":106,\"address\":\"Điểm\"}]}")]
    [InlineData("{\"items\":null}")]
    [InlineData("{}")]
    public async Task Broken_provider_data_fails_without_silently_substituting_demo_places(string body)
    {
        var map = new HttpMapProvider(new HttpClient(new Handler(_ => new(HttpStatusCode.OK) { Content = new StringContent(body) })), "https://maps.invalid");
        var error = await Assert.ThrowsAsync<RuleException>(() => map.Search("Quận 1", default));
        Assert.Equal(503, error.Status);
    }
}
