using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class StatisticsTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<(HttpClient Client, string UserId, string? DriverId)> Actor(string role)
    {
        var id = "statistics-" + Guid.NewGuid();
        string? driverId = null;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            db.Add(new User { Id = id, Name = "Thống kê", Phone = id, Role = role });
            if (role == Roles.Driver)
            {
                var driver = new Driver { UserId = id };
                driverId = driver.Id; db.Add(driver);
            }
            await db.SaveChangesAsync();
        }
        var client = factory.CreateClient();
        var session = await Read(await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = id }));
        client.DefaultRequestHeaders.Authorization = new("Bearer", session.GetProperty("accessToken").GetString());
        return (client, id, driverId);
    }

    private static async Task<JsonElement> Read(HttpResponseMessage response)
    {
        var text = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode}: {text}");
        return JsonDocument.Parse(text).RootElement.Clone();
    }

    private static void AddRide(GrapDbContext db, string customer, string? driver, DateTime ended,
        string status = "COMPLETED", long fare = 100, long paid = 25, string service = "BIKE", string? previousDriver = null)
    {
        var quote = new Quote { CustomerId = customer };
        var ride = new Ride { CustomerId = customer, DriverId = driver, QuoteId = quote.Id,
            CreatedAt = ended.AddDays(-5), EndedAt = ended, Status = status, ServiceTypeCode = service,
            Fare = new(fare, 0, 0, 0, fare, fare, fare / 5) };
        db.Add(quote); db.Add(ride);
        if (status == "COMPLETED" && driver != null)
            db.Add(new Payment { RideId = ride.Id, DriverId = driver, PayableAmount = fare, PaidAmount = paid });
        if (previousDriver != null)
            db.Add(new Assignment { RideId = ride.Id, DriverId = previousDriver, EndedAt = ended.AddMinutes(-1) });
    }

    [Fact]
    public async Task Customer_report_aggregates_all_rows_uses_vietnam_midnight_and_keeps_payable_separate_from_paid()
    {
        var customer = await Actor(Roles.Customer);
        var other = await Actor(Roles.Customer);
        var driver = await Actor(Roles.Driver);
        var start = new DateTime(2020, 5, 1, 17, 0, 0, DateTimeKind.Utc);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            for (var i = 0; i < 40; i++) AddRide(db, customer.UserId, driver.DriverId, start.AddMinutes(i));
            AddRide(db, customer.UserId, driver.DriverId, start.AddHours(1), fare: 500, paid: 500, service: "CAR_4");
            AddRide(db, customer.UserId, null, start.AddHours(2), "CANCELED");
            AddRide(db, customer.UserId, null, start.AddHours(3), "EXPIRED");
            AddRide(db, customer.UserId, driver.DriverId, start.AddTicks(-1));
            AddRide(db, customer.UserId, driver.DriverId, start.AddDays(1)); // exclusive upper boundary
            AddRide(db, other.UserId, driver.DriverId, start.AddMinutes(4));
            AddRide(db, customer.UserId, driver.DriverId, start.AddMinutes(5), "IN_PROGRESS");
            await db.SaveChangesAsync();
        }
        var result = await Read(await customer.Client.GetAsync("/api/v1/me/ride-statistics?from=2020-05-02&to=2020-05-02&userId=" + other.UserId));
        var totals = result.GetProperty("totals");
        Assert.Equal(43, totals.GetProperty("totalRides").GetInt32());
        Assert.Equal(41, totals.GetProperty("completedRides").GetInt32());
        Assert.Equal(1, totals.GetProperty("canceledRides").GetInt32());
        Assert.Equal(1, totals.GetProperty("unfulfilledRides").GetInt32());
        Assert.Equal(4500, totals.GetProperty("payable").GetInt64());
        Assert.Equal(1500, totals.GetProperty("paid").GetInt64());
        Assert.Equal(3000, totals.GetProperty("outstanding").GetInt64());
        Assert.Equal(0, totals.GetProperty("commission").GetInt64());
        Assert.Equal(0, totals.GetProperty("entitlement").GetInt64());
        Assert.Equal("2020-05-02", result.GetProperty("buckets")[0].GetProperty("date").GetString());
        Assert.Equal(2, result.GetProperty("services").GetArrayLength());
        Assert.Equal(4500, result.GetProperty("services").EnumerateArray().Sum(s => s.GetProperty("totals").GetProperty("payable").GetInt64()));
        Assert.DoesNotContain("customerId", result.GetRawText());
        Assert.DoesNotContain("phone", result.GetRawText());
    }

    [Fact]
    public async Task Driver_report_counts_only_final_driver_and_fills_zero_months_without_changing_balance()
    {
        var customer = await Actor(Roles.Customer);
        var driver = await Actor(Roles.Driver);
        var previous = await Actor(Roles.Driver);
        var at = new DateTime(2020, 5, 4, 4, 0, 0, DateTimeKind.Utc);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            AddRide(db, customer.UserId, driver.DriverId, at, fare: 500, paid: 200, previousDriver: previous.DriverId);
            AddRide(db, customer.UserId, driver.DriverId, at.AddHours(1), fare: 500, paid: 200);
            AddRide(db, customer.UserId, driver.DriverId, at.AddHours(2), "CANCELED");
            AddRide(db, customer.UserId, previous.DriverId, at, fare: 700, paid: 700);
            await db.SaveChangesAsync();
        }
        const string path = "/api/v1/me/ride-statistics?from=2020-05-01&to=2020-06-30";
        var result = await Read(await driver.Client.GetAsync(path));
        var totals = result.GetProperty("totals");
        Assert.Equal(3, totals.GetProperty("totalRides").GetInt32());
        Assert.Equal(2, totals.GetProperty("completedRides").GetInt32());
        Assert.Equal(1000, totals.GetProperty("grossFare").GetInt64());
        Assert.Equal(200, totals.GetProperty("commission").GetInt64());
        Assert.Equal(800, totals.GetProperty("entitlement").GetInt64());
        Assert.Equal(400, totals.GetProperty("paid").GetInt64());
        Assert.Equal(600, totals.GetProperty("outstanding").GetInt64());
        Assert.Equal("month", result.GetProperty("granularity").GetString());
        Assert.Equal(2, result.GetProperty("buckets").GetArrayLength());
        Assert.Equal(0, result.GetProperty("buckets")[1].GetProperty("totals").GetProperty("totalRides").GetInt32());
        var former = await Read(await previous.Client.GetAsync(path));
        Assert.Equal(1, former.GetProperty("totals").GetProperty("completedRides").GetInt32());
        Assert.Equal(560, former.GetProperty("totals").GetProperty("entitlement").GetInt64());
    }

    [Fact]
    public async Task Report_requires_user_role_valid_bounded_dates_and_returns_zero_for_an_empty_period()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/v1/me/ride-statistics")).StatusCode);
        var staff = await Actor(Roles.Operations);
        Assert.Equal(HttpStatusCode.Forbidden, (await staff.Client.GetAsync("/api/v1/me/ride-statistics")).StatusCode);
        var customer = await Actor(Roles.Customer);
        foreach (var query in new[] { "from=2020-01-01", "from=2020-01-02&to=2020-01-01", "from=2020-01-01&to=2021-01-01", "from=9999-01-01&to=9999-01-02", "from=oops&to=2020-01-01" })
            Assert.Equal(HttpStatusCode.BadRequest, (await customer.Client.GetAsync("/api/v1/me/ride-statistics?" + query)).StatusCode);
        var result = await Read(await customer.Client.GetAsync("/api/v1/me/ride-statistics"));
        Assert.Equal(0, result.GetProperty("totals").GetProperty("totalRides").GetInt32());
        Assert.Equal(7, result.GetProperty("buckets").GetArrayLength());
        Assert.All(result.GetProperty("buckets").EnumerateArray(), b => Assert.Equal(0, b.GetProperty("totals").GetProperty("payable").GetInt64()));
        await Read(await customer.Client.GetAsync("/api/v1/me/ride-statistics?from=2020-02-01&to=2021-01-31")); // 366 days, leap year
    }
}
