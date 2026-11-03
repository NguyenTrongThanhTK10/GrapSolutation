using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
namespace GrapSolution.Api;

public static partial class Endpoints
{
    private static void MapPush(RouteGroupBuilder auth)
    {
        auth.MapPut("/me/push-devices/{installationId}", (string installationId, PushDeviceRequest body, HttpContext ctx, AtomicExecutor atomic, ISecrets secrets, GrapDbContext db, IPushSender sender) => Write(ctx, atomic, secrets, body, async () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
            if (!Guid.TryParse(installationId, out _) || body.Platform is not ("android" or "ios") || body.AppType != (actor.Role == Roles.Customer ? "customer" : "driver") || string.IsNullOrWhiteSpace(body.Token) || body.Token.Length > 4096 || body.Token.Any(char.IsWhiteSpace))
                throw new RuleException("INVALID_PUSH_DEVICE", "Thông tin thiết bị hoặc token thông báo không hợp lệ.", 400);
            var hash = secrets.Hash(body.Token);
            var device = db.Set<PushDevice>().SingleOrDefault(d => d.InstallationId == installationId && d.AppType == body.AppType);
            var currentId = device?.Id ?? "";
            foreach (var old in db.Set<PushDevice>().Where(d => d.TokenHash == hash && d.RevokedAt == null && d.Id != currentId).ToList()) { old.RevokedAt = DateTime.UtcNow; old.TokenProtected = ""; }
            // Flush revoked unique-token slots before reusing them, within the same transaction.
            await db.SaveChangesAsync();
            if (device == null) { device = new PushDevice { InstallationId = installationId, AppType = body.AppType }; db.Add(device); }
            device.UserId = actor.Id; device.SessionId = actor.SessionId; device.Platform = body.Platform; device.TokenHash = hash; device.TokenProtected = secrets.Protect(body.Token); device.RevokedAt = null; device.LastSeenAt = DateTime.UtcNow;
            return new { device.Id, registered = true, deliveryEnabled = sender.Enabled };
        }));
        auth.MapPost("/me/push-test", (HttpContext ctx, AtomicExecutor atomic, ISecrets secrets, GrapDbContext db, IPushSender sender) => Write(ctx, atomic, secrets, new { }, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
            if (!sender.Enabled) throw new RuleException("PUSH_NOT_CONFIGURED", "Máy chủ chưa bật Firebase Admin hoặc chưa có thông tin xác thực gửi FCM.", 503);
            if (!db.Set<PushDevice>().Any(d => d.UserId == actor.Id && d.SessionId == actor.SessionId && d.RevokedAt == null)) throw new RuleException("PUSH_DEVICE_REQUIRED", "Cần bật thông báo trên thiết bị trước.", 422);
            if (db.Set<Notification>().Any(n => n.UserId == actor.Id && n.Kind == "test" && n.CreatedAt > DateTime.UtcNow.AddSeconds(-30))) throw new RuleException("RATE_LIMITED", "Đợi 30 giây trước khi gửi thử lại.", 429);
            var notification = new Notification { UserId = actor.Id, Kind = "test", Title = "Thông báo thử", Body = "Kết nối thông báo Grap đã được kiểm tra." }; db.Add(notification);
            return Task.FromResult<object?>(new { queued = true, notificationId = notification.Id });
        }, true));
        auth.MapDelete("/me/push-devices/{installationId}", (string installationId, HttpContext ctx, AtomicExecutor atomic, ISecrets secrets, GrapDbContext db) => Write(ctx, atomic, secrets, new { installationId }, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
            var devices = db.Set<PushDevice>().Where(d => d.InstallationId == installationId && d.UserId == actor.Id && d.SessionId == actor.SessionId && d.RevokedAt == null).ToList();
            foreach (var device in devices) { device.RevokedAt = DateTime.UtcNow; device.TokenProtected = ""; }
            return Task.FromResult<object?>(new { success = true });
        }));
    }
}
public record PushDeviceRequest(string Token, string Platform, string AppType);
