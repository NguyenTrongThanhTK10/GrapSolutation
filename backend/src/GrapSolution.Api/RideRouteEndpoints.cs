using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GrapSolution.Api;

public static partial class Endpoints
{
    private static void MapRideRoutes(RouteGroupBuilder auth)
    {
        auth.MapGet("/rides/{id}/route", async (string id, HttpContext ctx, RideService service, GrapDbContext db, CancellationToken ct) =>
        {
            var ride = service.AuthorizedRide(ctx.Actor(), id);
            var quote = await db.Set<Quote>().AsNoTracking().SingleAsync(q => q.Id == ride.QuoteId, ct);
            var startedAt = await db.Set<RideEvent>().Where(e => e.RideId == id && e.EventType == "start")
                .Select(e => (DateTime?)e.CreatedAt).MinAsync(ct);
            var until = ride.EndedAt ?? DateTime.UtcNow;
            // Only expose GPS recorded while this passenger was on this ride.
            // Assignment bounds also exclude a released driver's later locations.
            var samples = await db.Set<LocationSample>().AsNoTracking()
                .Where(s => startedAt != null && s.RecordedAt >= startedAt && s.RecordedAt <= until &&
                    s.AccuracyMeters > 0 && s.AccuracyMeters <= 100 &&
                    s.Latitude >= -90 && s.Latitude <= 90 && s.Longitude >= -180 && s.Longitude <= 180 &&
                    db.Set<Assignment>().Any(a => a.RideId == id && a.DriverId == s.DriverId &&
                        s.RecordedAt >= a.CreatedAt && (a.EndedAt == null || s.RecordedAt <= a.EndedAt)))
                .OrderBy(s => s.RecordedAt).ThenBy(s => s.Sequence)
                .Select(s => new { s.Latitude, s.Longitude, s.RecordedAt })
                .ToListAsync(ct);
            return new { rideId = id, quote.DistanceMeters, quote.DurationSeconds, quote.RouteSource,
                geometry = quote.RouteGeometry, samples, serverTime = DateTime.UtcNow };
        });
    }
}
