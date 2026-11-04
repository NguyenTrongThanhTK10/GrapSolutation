using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;

namespace GrapSolution.Api;

public static partial class Endpoints
{
    private sealed record StatisticsRide(DateTime EndedAt, string Status, string Service,
        long GrossFare, long Commission, long Payable, long Paid);

    private sealed record StatisticsTotals(int TotalRides, int CompletedRides, int CanceledRides,
        int UnfulfilledRides, long GrossFare, long Commission, long Entitlement,
        long Payable, long Paid, long Outstanding);

    private static StatisticsTotals SummarizeStatistics(IEnumerable<StatisticsRide> source, bool driver)
    {
        var rides = source.ToList();
        var completed = rides.Where(r => r.Status == "COMPLETED").ToList();
        var gross = completed.Sum(r => r.GrossFare);
        var commission = completed.Sum(r => r.Commission);
        return new(rides.Count, completed.Count, rides.Count(r => r.Status == "CANCELED"),
            rides.Count(r => r.Status is "NO_DRIVER" or "EXPIRED"), gross, driver ? commission : 0, driver ? gross - commission : 0,
            completed.Sum(r => r.Payable), completed.Sum(r => r.Paid),
            completed.Sum(r => Math.Max(0, r.Payable - r.Paid)));
    }

    private static void MapStatistics(RouteGroupBuilder auth)
    {
        auth.MapGet("/me/ride-statistics", (HttpContext ctx, GrapDbContext db, RideService service,
            DateOnly? from, DateOnly? to) =>
        {
            var actor = ctx.Actor();
            actor.Require(Roles.Customer, Roles.Driver);
            var timezone = TimeZoneInfo.FindSystemTimeZoneById("Asia/Ho_Chi_Minh");
            var now = DateTime.UtcNow;
            var today = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(now, timezone));
            if (from.HasValue != to.HasValue)
                throw new RuleException("VALIDATION_ERROR", "Cần chọn cả ngày bắt đầu và ngày kết thúc.", 400);
            var first = from ?? today.AddDays(-6);
            var last = to ?? today;
            if (first > last || last.DayNumber - first.DayNumber >= 366 || last > today)
                throw new RuleException("VALIDATION_ERROR", "Chọn khoảng tối đa 366 ngày, không vượt quá hôm nay.", 400);
            var start = TimeZoneInfo.ConvertTimeToUtc(first.ToDateTime(TimeOnly.MinValue), timezone);
            var end = TimeZoneInfo.ConvertTimeToUtc(last.AddDays(1).ToDateTime(TimeOnly.MinValue), timezone);
            var query = db.Set<Ride>().Where(r => r.EndedAt >= start && r.EndedAt < end &&
                (r.Status == "COMPLETED" || r.Status == "CANCELED" || r.Status == "NO_DRIVER" || r.Status == "EXPIRED"));
            if (actor.Role == Roles.Customer) query = query.Where(r => r.CustomerId == actor.Id);
            else
            {
                // A previous assignment does not earn the final driver's fare.
                var driverId = service.DriverFor(actor).Id;
                query = query.Where(r => r.DriverId == driverId);
            }
            var rides = query.Select(r => new StatisticsRide(r.EndedAt!.Value, r.Status, r.ServiceTypeCode,
                r.Fare.GrossFare, r.Fare.PlatformCommission, r.Fare.CustomerPayable,
                db.Set<Payment>().Where(p => p.RideId == r.Id).Select(p => p.PaidAmount).FirstOrDefault())).ToList();
            var monthly = last.DayNumber - first.DayNumber >= 31;
            DateOnly Bucket(DateTime at)
            {
                var local = DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(at, DateTimeKind.Utc), timezone));
                return monthly ? new(local.Year, local.Month, 1) : local;
            }
            var grouped = rides.GroupBy(r => Bucket(r.EndedAt)).ToDictionary(g => g.Key, g => g.ToList());
            var dates = new List<DateOnly>();
            for (var date = monthly ? new DateOnly(first.Year, first.Month, 1) : first;
                date <= last; date = monthly ? date.AddMonths(1) : date.AddDays(1)) dates.Add(date);
            return Results.Ok(new
            {
                from = first, to = last, timezone = "Asia/Ho_Chi_Minh", currency = "VND",
                role = actor.Role, generatedAt = now, granularity = monthly ? "month" : "day",
                totals = SummarizeStatistics(rides, actor.Role == Roles.Driver),
                buckets = dates.Select(date => new { date, totals = SummarizeStatistics(grouped.GetValueOrDefault(date) ?? [], actor.Role == Roles.Driver) }),
                services = rides.GroupBy(r => r.Service).OrderBy(g => g.Key)
                    .Select(g => new { service = g.Key, totals = SummarizeStatistics(g, actor.Role == Roles.Driver) })
            });
        });
    }
}
