using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class RideRouteTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string user)
    {
        var client = factory.CreateClient();
        var response = await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = user, deviceId = Guid.NewGuid().ToString() });
        response.EnsureSuccessStatusCode();
        var session = await response.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new("Bearer", session.GetProperty("accessToken").GetString());
        return client;
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Route_returns_persisted_geometry_and_only_samples_during_the_passengers_ride(bool started)
    {
        var customer = await Login("customer-7");
        var other = await Login("customer-6");
        var driver = await Login("driver-user-9");
        var unrelatedDriver = await Login("driver-user-8");
        string rideId;
        var start = DateTime.UtcNow.AddHours(-2);
        const string geometry = "{\"type\":\"LineString\",\"coordinates\":[[106.69,10.77],[106.71,10.78],[106.72,10.79]]}";
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            var d = db.Set<Driver>().Single(d => d.UserId == "driver-user-9");
            var quote = new Quote { CustomerId = "customer-7", RouteGeometry = geometry, DistanceMeters = 6300, DurationSeconds = 1200 };
            var ride = new Ride { CustomerId = "customer-7", DriverId = d.Id, QuoteId = quote.Id,
                Status = started ? "COMPLETED" : "CANCELED", CreatedAt = start.AddMinutes(-10), EndedAt = start.AddMinutes(30) };
            rideId = ride.Id;
            db.Add(quote); db.Add(ride);
            db.Add(new Assignment { RideId = ride.Id, DriverId = d.Id, CreatedAt = start.AddMinutes(-5), EndedAt = start.AddMinutes(20) });
            if (started) db.Add(new RideEvent { RideId = ride.Id, EventType = "start", CreatedAt = start });
            void Sample(int minute, double accuracy = 10) => db.Add(new LocationSample {
                DriverId = d.Id, SessionId = Guid.NewGuid().ToString(), SampleId = Guid.NewGuid().ToString(),
                Sequence = minute + 100, Latitude = 10.77, Longitude = 106.69,
                AccuracyMeters = accuracy, RecordedAt = start.AddMinutes(minute) });
            Sample(-1); // Before the passenger boarded.
            Sample(1); Sample(2);
            Sample(3, 200); // Untrusted GPS.
            Sample(21); // After this driver's assignment ended.
            Sample(31); // After the ride ended.
            await db.SaveChangesAsync();
        }
        var path = "/api/v1/rides/" + rideId + "/route";
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync(path)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await other.GetAsync(path)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await unrelatedDriver.GetAsync(path)).StatusCode);
        foreach (var client in new[] { customer, driver })
        {
            var response = await client.GetAsync(path);
            response.EnsureSuccessStatusCode();
            var result = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(geometry, result.GetProperty("geometry").GetString());
            Assert.Equal(6300, result.GetProperty("distanceMeters").GetInt32());
            Assert.Equal(started ? 2 : 0, result.GetProperty("samples").GetArrayLength());
            var raw = result.GetRawText();
            Assert.DoesNotContain("sessionId", raw);
            Assert.DoesNotContain("driverId", raw);
        }
    }
}
