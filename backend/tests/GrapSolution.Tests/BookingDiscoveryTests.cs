using System.Net;
using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class BookingDiscoveryTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string id, ApiFactory? source = null)
    {
        var c = (source ?? factory).CreateClient();
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
        string bikeId;
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
            bikeId = Add().Id; Add("CAR_7");
            Add().Online = false;
            Add().LocationAt = now.AddMinutes(-5);
            Add().HeartbeatAt = now.AddMinutes(-5);
            Add().DocumentsExpireAt = now.AddDays(-1);
            Add().ReviewStatus = "PENDING_REVIEW";
            Add().Accuracy = 500;
            Add().Accuracy = 0;
            Add().LocationAt = now.AddMinutes(1);
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

        const string locations = "/api/v1/customers/me/nearby-drivers?latitude=10.7721&longitude=106.6983";
        var snapshot = (await c.GetFromJsonAsync<JsonElement>(locations));
        var markers = snapshot.GetProperty("drivers");
        Assert.Equal(2, markers.GetArrayLength());
        foreach (var field in new[] { "driverId", "userId", "plate", "phone", "Private Driver", bikeId }) Assert.DoesNotContain(field, markers.GetRawText());
        var bike = markers.EnumerateArray().Single(m => m.GetProperty("serviceTypeCode").GetString() == "BIKE");
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            var d = await db.Set<Driver>().FindAsync(bikeId);
            d!.Latitude = 10.773234; d.Longitude = 106.699456; d.LocationAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        var moved = await c.GetFromJsonAsync<JsonElement>(locations);
        var movedBike = moved.GetProperty("drivers").EnumerateArray().Single(m => m.GetProperty("serviceTypeCode").GetString() == "BIKE");
        Assert.Equal(bike.GetProperty("markerId").GetString(), movedBike.GetProperty("markerId").GetString());
        Assert.Equal(10.7732, movedBike.GetProperty("latitude").GetDouble());
        Assert.Equal(106.6995, movedBike.GetProperty("longitude").GetDouble());
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            (await db.Set<Driver>().FindAsync(bikeId))!.LocationAt = DateTime.UtcNow.AddSeconds(-31);
            await db.SaveChangesAsync();
        }
        var stale = await c.GetFromJsonAsync<JsonElement>(locations);
        Assert.DoesNotContain(stale.GetProperty("drivers").EnumerateArray(), m => m.GetProperty("serviceTypeCode").GetString() == "BIKE");
    }
    [Theory]
    [InlineData("/api/v1/customers/me/nearby-services")]
    [InlineData("/api/v1/customers/me/nearby-drivers")]
    public async Task Nearby_requires_customer_role_and_valid_coordinate_and_handles_outside_service_area(string path)
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync(path + "?latitude=10&longitude=106")).StatusCode);
        var driver = await Login("driver-user-9");
        Assert.Equal(HttpStatusCode.Forbidden, (await driver.GetAsync(path + "?latitude=10&longitude=106")).StatusCode);
        var customer = await Login("customer-6");
        Assert.Equal(HttpStatusCode.BadRequest, (await customer.GetAsync(path + "?latitude=91&longitude=106")).StatusCode);
        var response = await customer.GetAsync(path + "?latitude=21.03&longitude=105.85"); response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.False(json.GetProperty("inServiceZone").GetBoolean());
        Assert.All(json.GetProperty("items").EnumerateArray(), item => Assert.Equal(0, item.GetProperty("availableCount").GetInt32()));
        if (json.TryGetProperty("drivers", out var markers)) Assert.Equal(0, markers.GetArrayLength());
    }

    private static async Task<JsonElement> ReceiveHub(WebSocket socket, Func<JsonElement, bool> match, CancellationToken ct)
    {
        var buffer = new byte[8192]; var pending = "";
        while (true)
        {
            var received = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), ct);
            Assert.NotEqual(WebSocketMessageType.Close, received.MessageType);
            pending += Encoding.UTF8.GetString(buffer, 0, received.Count);
            while (pending.IndexOf('\u001e') is var end && end >= 0)
            {
                using var document = JsonDocument.Parse(pending[..end]); pending = pending[(end + 1)..];
                if (match(document.RootElement)) return document.RootElement.Clone();
            }
        }
    }
    [Fact]
    public async Task Nearby_subscription_receives_location_invalidation_without_driver_data_and_rejects_driver_role()
    {
        using var source = new ApiFactory();
        var customer = await Login("customer-0", source);
        var driver = await Login("driver-user-0", source);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        async Task<WebSocket> Connect(HttpClient client)
        {
            var websocket = source.Server.CreateWebSocketClient();
            websocket.ConfigureRequest = request => request.Headers.Authorization = client.DefaultRequestHeaders.Authorization!.ToString();
            var socket = await websocket.ConnectAsync(new Uri("ws://localhost/hubs/rides"), timeout.Token);
            await socket.SendAsync(Encoding.UTF8.GetBytes("{\"protocol\":\"json\",\"version\":1}\u001e"), WebSocketMessageType.Text, true, timeout.Token);
            await ReceiveHub(socket, j => !j.TryGetProperty("type", out _), timeout.Token);
            return socket;
        }
        const string subscribe = "{\"type\":1,\"invocationId\":\"1\",\"target\":\"SubscribeNearby\",\"arguments\":[10.7721,106.6983]}\u001e";
        using var customerSocket = await Connect(customer);
        await customerSocket.SendAsync(Encoding.UTF8.GetBytes(subscribe), WebSocketMessageType.Text, true, timeout.Token);
        var completion = await ReceiveHub(customerSocket, j => j.TryGetProperty("invocationId", out _), timeout.Token);
        Assert.False(completion.TryGetProperty("error", out _));
        using var driverSocket = await Connect(driver);
        await driverSocket.SendAsync(Encoding.UTF8.GetBytes(subscribe), WebSocketMessageType.Text, true, timeout.Token);
        var denied = await ReceiveHub(driverSocket, j => j.TryGetProperty("invocationId", out _), timeout.Token);
        Assert.True(denied.TryGetProperty("error", out _));
        var availability = await driver.GetFromJsonAsync<JsonElement>("/api/v1/drivers/me/availability");
        (await driver.PostAsJsonAsync("/api/v1/drivers/me/availability", new { online = true, expectedVersion = availability.GetProperty("version").GetInt32() })).EnsureSuccessStatusCode();
        (await driver.PostAsync("/api/v1/drivers/me/heartbeat", null)).EnsureSuccessStatusCode();
        (await driver.PostAsJsonAsync("/api/v1/drivers/me/location-batches", new { samples = new[] { new { latitude = 10.7721, longitude = 106.6983, accuracyMeters = 10, recordedAt = DateTime.UtcNow, sequence = 1 } } })).EnsureSuccessStatusCode();
        var update = await ReceiveHub(customerSocket, j => j.TryGetProperty("target", out var target) && target.GetString() == "nearby.drivers.changed", timeout.Token);
        Assert.DoesNotContain("latitude", update.GetRawText()); Assert.DoesNotContain("driverId", update.GetRawText());
        var snapshot = await customer.GetFromJsonAsync<JsonElement>("/api/v1/customers/me/nearby-drivers?latitude=10.7721&longitude=106.6983");
        Assert.Single(snapshot.GetProperty("drivers").EnumerateArray());
        (await driver.PostAsJsonAsync("/api/v1/drivers/me/availability", new { online = false, expectedVersion = availability.GetProperty("version").GetInt32() + 1 })).EnsureSuccessStatusCode();
        var offline = await customer.GetFromJsonAsync<JsonElement>("/api/v1/customers/me/nearby-drivers?latitude=10.7721&longitude=106.6983");
        Assert.Empty(offline.GetProperty("drivers").EnumerateArray());
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
