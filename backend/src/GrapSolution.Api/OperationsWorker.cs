using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Api;

[Authorize]
public sealed class RideHub(GrapDbContext db) : Hub
{
    public override async Task OnConnectedAsync() { var actor = Context.GetHttpContext()!.Actor(); if (await db.Set<Session>().AnyAsync(s => s.Id == actor.SessionId && s.RevokedAt == null)) await Groups.AddToGroupAsync(Context.ConnectionId, "session:" + actor.SessionId); else Context.Abort(); await base.OnConnectedAsync(); }
    // Membership is assigned by the server. Clients cannot join arbitrary ride or operations groups.
    public async Task SubscribeNearby(double latitude, double longitude)
    {
        var actor = Context.GetHttpContext()!.Actor();
        actor.Require(Roles.Customer);
        if (!await db.Set<Session>().AnyAsync(s => s.Id == actor.SessionId && s.UserId == actor.Id &&
                s.RevokedAt == null && s.ExpiresAt > DateTime.UtcNow)) throw new HubException("SESSION_EXPIRED");
        var pickup = new GeoPoint(latitude, longitude, "Điểm đón"); pickup.Validate();
        var zone = (await db.Set<ServiceZone>().Where(z => z.Active).ToListAsync())
            .FirstOrDefault(z => RideService.Contains(z.PolygonJson, pickup));
        if (Context.Items.Remove("nearbyZone", out var previous) && previous is string previousZone)
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, "nearby:" + previousZone);
        if (zone != null)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "nearby:" + zone.Id);
            Context.Items["nearbyZone"] = zone.Id;
        }
    }
}
public sealed class OperationsWorker(IServiceScopeFactory factory, IHubContext<RideHub> hub, ILogger<OperationsWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(2));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                await using var scope = factory.CreateAsyncScope(); var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var service = scope.ServiceProvider.GetRequiredService<RideService>(); var atomic = scope.ServiceProvider.GetRequiredService<AtomicExecutor>();
                await atomic.Run("system", "dispatch", null, "", async () => { await db.SaveChangesAsync(stoppingToken); await service.Dispatch(stoppingToken); return null; }, ct: stoppingToken);
                var pending = await db.Set<OutboxMessage>().Where(o => o.PublishedAt == null && o.Attempts < 10 && o.NextAttemptAt <= DateTime.UtcNow).OrderBy(o => o.CreatedAt).Take(50).ToListAsync(stoppingToken);
                foreach (var message in pending)
                {
                    try
                    {
                        // Nearby groups receive only an invalidation. Coordinates are fetched through authenticated REST.
                        if (message.EventType == "nearby.drivers.changed")
                        {
                            await hub.Clients.Group("nearby:" + message.AggregateId).SendAsync("nearby.drivers.changed", new { serverTime = DateTime.UtcNow }, stoppingToken);
                            message.PublishedAt = DateTime.UtcNow;
                            continue;
                        }
                        if (message.EventType == "ride.message.created")
                        {
                            var data = JsonSerializer.Deserialize<JsonElement>(message.Payload);
                            var assignmentId = data.GetProperty("assignmentId").GetString();
                            var assignment = await db.Set<Assignment>().AsNoTracking().SingleOrDefaultAsync(a => a.Id == assignmentId, stoppingToken);
                            var ride = await db.Set<Ride>().AsNoTracking().SingleOrDefaultAsync(r => r.Id == message.AggregateId, stoppingToken);
                            // An old outbox event must never reach the replacement driver or staff sessions.
                            if (ride != null && assignment != null && assignment.EndedAt == null && ride.DriverId == assignment.DriverId)
                            {
                                var driverUser = await db.Set<Driver>().Where(d => d.Id == assignment.DriverId).Select(d => d.UserId).SingleAsync(stoppingToken);
                                var recipients = await db.Set<Session>().Where(s => (s.UserId == ride.CustomerId || s.UserId == driverUser) && s.RevokedAt == null && s.ExpiresAt > DateTime.UtcNow)
                                    .Select(s => "session:" + s.Id).ToListAsync(stoppingToken);
                                await hub.Clients.Groups(recipients).SendAsync(message.EventType, new { aggregateId = ride.Id, data }, stoppingToken);
                            }
                            message.PublishedAt = DateTime.UtcNow;
                            continue;
                        }
                        var userIds = new HashSet<string>(); var zoneId = "";
                        if (message.EventType.StartsWith("driver.offer", StringComparison.Ordinal)) { userIds.Add(message.AggregateId); zoneId = (await db.Set<User>().FindAsync([message.AggregateId], stoppingToken))?.ZoneId ?? ""; }
                        else { var ride = await db.Set<Ride>().FindAsync([message.AggregateId], stoppingToken); if (ride != null) { zoneId = ride.ZoneId; userIds.Add(ride.CustomerId); if (ride.DriverId != null) { var driver = await db.Set<Driver>().FindAsync([ride.DriverId], stoppingToken); if (driver != null) userIds.Add(driver.UserId); } } }
                        var staff = await db.Set<User>().Where(u => (u.Role == Roles.Dispatcher || u.Role == Roles.Operations || u.Role == Roles.Support) && u.ZoneId == zoneId && u.Status == "ACTIVE").Select(u => u.Id).ToListAsync(stoppingToken); userIds.UnionWith(staff);
                        var sessions = await db.Set<Session>().Where(s => userIds.Contains(s.UserId) && s.RevokedAt == null && s.ExpiresAt > DateTime.UtcNow).Select(s => s.Id).ToListAsync(stoppingToken);
                        var envelope = new { eventId = message.Id, eventType = message.EventType, schemaVersion = 1, occurredAt = message.CreatedAt, aggregateId = message.AggregateId, aggregateVersion = message.AggregateVersion, data = JsonSerializer.Deserialize<JsonElement>(message.Payload) };
                        await hub.Clients.Groups(sessions.Select(s => "session:" + s).ToArray()).SendAsync(message.EventType, envelope, stoppingToken);
                        if (zoneId.Length > 0 && (message.EventType.StartsWith("driver.offer", StringComparison.Ordinal) || message.EventType == "ride.status.changed"))
                            await hub.Clients.Group("nearby:" + zoneId).SendAsync("nearby.drivers.changed", new { serverTime = DateTime.UtcNow }, stoppingToken);
                        message.PublishedAt = DateTime.UtcNow;
                    }
                    catch (Exception ex) when (ex is not OperationCanceledException) { message.Attempts++; message.NextAttemptAt = DateTime.UtcNow.AddSeconds(Math.Min(300, Math.Pow(2, message.Attempts))); logger.LogWarning("Outbox retry {EventId} {Attempt}", message.Id, message.Attempts); }
                }
                if (pending.Count > 0) await db.SaveChangesAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Operations worker iteration failed"); }
        }
    }
}
