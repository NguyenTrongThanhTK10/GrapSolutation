using GrapSolution.Application;
using GrapSolution.Domain;
using Microsoft.EntityFrameworkCore;

namespace GrapSolution.Infrastructure;

public sealed class PushDispatcher(GrapDbContext db, IPushSender sender, ISecrets secrets)
{
    public async Task Process(CancellationToken ct = default)
    {
        if (!sender.Enabled) return;
        var now = DateTime.UtcNow;
        var batch = await db.Set<PushDelivery>().Where(d => d.Status == "PENDING" && d.NextAttemptAt <= now).OrderBy(d => d.CreatedAt).Take(40).ToListAsync(ct);
        foreach (var delivery in batch)
        {
            ct.ThrowIfCancellationRequested();
            // Conditional claim prevents concurrent worker instances from sending the same row together.
            var lease = now.AddMinutes(2);
            var claimed = await db.Set<PushDelivery>().Where(d => d.Id == delivery.Id && d.Status == "PENDING" && d.NextAttemptAt <= now)
                .ExecuteUpdateAsync(s => s.SetProperty(d => d.NextAttemptAt, lease), ct);
            if (claimed == 0) continue;
            delivery.NextAttemptAt = lease;
            var device = await db.Set<PushDevice>().AsNoTracking().SingleOrDefaultAsync(d => d.Id == delivery.DeviceId, ct);
            var notification = await db.Set<Notification>().FindAsync([delivery.NotificationId], ct);
            if (delivery.ExpiresAt <= now) { delivery.Status = "EXPIRED"; }
            else if (device == null || notification == null || device.RevokedAt != null || device.UserId != delivery.UserId || device.SessionId != delivery.SessionId || device.TokenHash != delivery.TokenHash ||
                !await db.Set<Session>().AnyAsync(s => s.Id == delivery.SessionId && s.UserId == delivery.UserId && s.RevokedAt == null && s.ExpiresAt > now, ct) ||
                !await db.Set<User>().AnyAsync(u => u.Id == delivery.UserId && u.Status == "ACTIVE", ct)) { delivery.Status = "SKIPPED"; }
            else if (notification.Kind == "offer" && !await db.Set<Offer>().AnyAsync(o => o.Id == notification.EntityId && o.Status == "OPEN" && o.ExpiresAt > now && db.Set<Driver>().Any(d => d.Id == o.DriverId && d.UserId == delivery.UserId && d.ActiveSessionId == delivery.SessionId), ct)) { delivery.Status = "EXPIRED"; }
            else
            {
                // Use a generic lock-screen message. No address, PIN, GPS or support contents are sent to FCM.
                var data = new Dictionary<string, string> { ["notificationId"] = notification.Id, ["eventId"] = notification.Id, ["userId"] = delivery.UserId, ["entityType"] = notification.Kind, ["entityId"] = notification.EntityId ?? "" };
                delivery.Attempts++;
                PushSendResult result;
                try { result = await sender.Send(new(secrets.Unprotect(device.TokenProtected), "Grap · Có cập nhật mới", notification.Kind == "offer" ? "Bạn có lời mời chuyến. Mở ứng dụng để kiểm tra." : "Mở ứng dụng để xem thông báo mới nhất.", data, delivery.ExpiresAt - now), ct); }
                catch (Exception ex) when (ex is not OperationCanceledException) { result = PushSendResult.Retry("PROVIDER_UNAVAILABLE"); }
                delivery.LastError = result.Error;
                if (result.Status == "SENT") { delivery.Status = "SENT"; delivery.SentAt = DateTime.UtcNow; }
                else if (result.Status == "INVALID_TOKEN")
                {
                    delivery.Status = "INVALID_TOKEN";
                    await db.Set<PushDevice>().Where(d => d.Id == device.Id && d.TokenHash == delivery.TokenHash).ExecuteUpdateAsync(s => s.SetProperty(d => d.RevokedAt, DateTime.UtcNow).SetProperty(d => d.TokenProtected, ""), ct);
                }
                else if (result.Status == "FAILED" || delivery.Attempts >= 8) { delivery.Status = "FAILED"; }
                else { delivery.NextAttemptAt = DateTime.UtcNow.Add(result.RetryAfter ?? TimeSpan.FromSeconds(Math.Min(300, Math.Pow(2, delivery.Attempts)))); }
            }
            await db.SaveChangesAsync(ct);
        }
    }
}
