using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Api;
public static partial class Endpoints
{
    private sealed record HistoryCursor(DateTime At, string Id, string Scope);
    private static object RideHistory(HttpContext ctx, GrapDbContext db, RideService service, ISecrets secrets, string? status, string? cursor, int? pageSize, DateTimeOffset? from, DateTimeOffset? to)
    {
        var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
        if (status != null && status != "ACTIVE" && !new[] { "SEARCHING", "ASSIGNED", "DRIVER_ARRIVED", "IN_PROGRESS", "COMPLETED", "CANCELED", "NO_DRIVER", "EXPIRED" }.Contains(status)) throw new RuleException("VALIDATION_ERROR", "Bộ lọc trạng thái không hợp lệ.", 400);
        if (from.HasValue && to.HasValue && from >= to) throw new RuleException("VALIDATION_ERROR", "Ngày bắt đầu phải trước ngày kết thúc.", 400);
        var take = Math.Clamp(pageSize ?? 20, 1, 100);
        var scope = secrets.Hash(string.Join('|', actor.Id, actor.Role, status ?? "", from?.UtcDateTime.ToString("O") ?? "", to?.UtcDateTime.ToString("O") ?? ""));
        IQueryable<Ride> query = db.Set<Ride>();
        if (actor.Role == Roles.Customer) query = query.Where(r => r.CustomerId == actor.Id);
        else
        {
            var driverId = service.DriverFor(actor).Id;
            query = query.Where(r => db.Set<Assignment>().Any(a => a.RideId == r.Id && a.DriverId == driverId && (a.EndedAt == null || !RideStates.Active.Contains(r.Status))));
        }
        if (status == "ACTIVE") query = query.Where(r => RideStates.Active.Contains(r.Status));
        else if (status != null) query = query.Where(r => r.Status == status);
        if (from.HasValue) { var start = from.Value.UtcDateTime; query = query.Where(r => r.CreatedAt >= start); }
        if (to.HasValue) { var end = to.Value.UtcDateTime; query = query.Where(r => r.CreatedAt < end); }
        if (cursor != null)
        {
            HistoryCursor decoded;
            try
            {
                if (cursor.Length > 2048) throw new FormatException(); var parts = cursor.Split('.'); if (parts.Length != 2) throw new FormatException();
                var signed = secrets.Hmac(parts[0]); if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(signed), Encoding.UTF8.GetBytes(parts[1]))) throw new FormatException();
                decoded = JsonSerializer.Deserialize<HistoryCursor>(Convert.FromBase64String(parts[0])) ?? throw new FormatException();
                if (decoded.Scope != scope || decoded.At.Kind != DateTimeKind.Utc || string.IsNullOrWhiteSpace(decoded.Id)) throw new FormatException();
            }
            catch (Exception ex) when (ex is FormatException or JsonException) { throw new RuleException("INVALID_CURSOR", "Cursor không hợp lệ hoặc không khớp tài khoản/bộ lọc.", 400); }
            var at = decoded.At; var id = decoded.Id;
            query = query.Where(r => r.CreatedAt < at || r.CreatedAt == at && string.Compare(r.Id, id) < 0);
        }
        var batch = query.OrderByDescending(r => r.CreatedAt).ThenByDescending(r => r.Id).Take(take + 1).ToList();
        var more = batch.Count > take; var rows = batch.Take(take).ToList(); string? next = null;
        if (more)
        {
            var last = rows[^1]; var payload = Convert.ToBase64String(JsonSerializer.SerializeToUtf8Bytes(new HistoryCursor(DateTime.SpecifyKind(last.CreatedAt, DateTimeKind.Utc), last.Id, scope)));
            next = payload + "." + secrets.Hmac(payload);
        }
        return new { items = rows.Select(r => service.Snapshot(actor, r)), nextCursor = next, hasMore = more, serverTime = DateTime.UtcNow };
    }
    private static void MapReceiptFeatures(RouteGroupBuilder auth)
    {
        auth.MapGet("/rides/{id}/ratings/me", (string id, HttpContext ctx, RideService service, GrapDbContext db) =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var ride = service.AuthorizedRide(actor, id);
            var rating = db.Set<Rating>().SingleOrDefault(r => r.RideId == id && r.AuthorId == actor.Id);
            return new { rating = rating == null ? null : new { rating.Stars, rating.Comment, rating.CreatedAt }, canEdit = ride.Status == "COMPLETED" && ride.EndedAt > DateTime.UtcNow.AddDays(-1), editableUntil = ride.EndedAt?.AddDays(1), serverTime = DateTime.UtcNow };
        });
    }
}
