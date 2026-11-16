using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;

namespace GrapSolution.Api;

public static partial class Endpoints
{
    private static void MapRideChat(RouteGroupBuilder auth)
    {
        auth.MapGet("/rides/{id}/messages", (string id, int? beforeSequence, int? afterSequence,
            HttpContext ctx, GrapDbContext db, ISecrets secrets) =>
        {
            if (beforeSequence is <= 0 || afterSequence is < 0 || beforeSequence != null && afterSequence != null)
                throw new RuleException("VALIDATION_ERROR", "Mốc phân trang tin nhắn không hợp lệ.", 400);
            var access = ChatAccess(id, ctx.Actor(), db);
            var query = db.Set<RideChatMessage>().AsNoTracking().Where(m => m.AssignmentId == access.Assignment.Id);
            if (beforeSequence != null) query = query.Where(m => m.Sequence < beforeSequence);
            if (afterSequence != null) query = query.Where(m => m.Sequence > afterSequence);
            var rows = (afterSequence != null ? query.OrderBy(m => m.Sequence) : query.OrderByDescending(m => m.Sequence))
                .Take(51).ToList();
            var hasMore = rows.Count > 50;
            rows = rows.Take(50).OrderBy(m => m.Sequence).ToList();
            return new
            {
                assignmentId = access.Assignment.Id, rideCode = access.Ride.Code,
                peerName = access.Peer.Name, canSend = ChatCanSend(access.Ride, access.Assignment),
                items = rows.Select(m => ChatMessageView(m, secrets)), hasMore,
                nextBeforeSequence = afterSequence == null && hasMore ? (int?)rows[0].Sequence : null
            };
        });
        auth.MapPost("/rides/{id}/messages", (string id, SendRideMessage body, HttpContext ctx,
            GrapDbContext db, ISecrets secrets, AtomicExecutor executor) =>
        {
            return Write(ctx, executor, secrets, body, () =>
            {
                var current = ChatAccess(id, ctx.Actor(), db);
                RequireChatAssignment(body.AssignmentId, current.Assignment);
                if (!ChatCanSend(current.Ride, current.Assignment))
                    throw new RuleException("CHAT_CLOSED", "Chuyến đã kết thúc. Bạn chỉ có thể xem lại tin nhắn.");
                var text = body.Body?.Trim() ?? "";
                if (text.Length is < 1 or > 1000 || text.Any(c => char.IsControl(c) && c is not '\n' and not '\r' and not '\t'))
                    throw new RuleException("VALIDATION_ERROR", "Tin nhắn cần từ 1–1.000 ký tự.", 400);
                var message = new RideChatMessage
                {
                    RideId = id, AssignmentId = current.Assignment.Id, SenderId = ctx.Actor().Id,
                    BodyProtected = secrets.Protect(text),
                    Sequence = (db.Set<RideChatMessage>().Where(m => m.AssignmentId == current.Assignment.Id)
                        .Select(m => (int?)m.Sequence).Max() ?? 0) + 1
                };
                db.Add(message);
                // Bodies stay out of realtime events, notification previews, and audit logs.
                db.Add(new OutboxMessage
                {
                    EventType = "ride.message.created", AggregateId = id,
                    Payload = JsonSerializer.Serialize(new { assignmentId = current.Assignment.Id, messageId = message.Id, sequence = message.Sequence })
                });
                db.Add(new Notification
                {
                    UserId = current.Peer.Id, Kind = "chat", EntityId = id,
                    Title = "Tin nhắn chuyến xe", Body = "Bạn có tin nhắn mới trong chuyến xe."
                });
                return Task.FromResult<object?>(ChatMessageView(message, secrets));
            }, true, 201, authorize: () =>
            {
                db.ChangeTracker.Clear();
                var access = ChatAccess(id, ctx.Actor(), db);
                RequireChatAssignment(body.AssignmentId, access.Assignment);
            });
        }).RequireRateLimiting("chat");
    }

    private static (Ride Ride, Assignment Assignment, User Peer) ChatAccess(string id, Actor actor, GrapDbContext db)
    {
        actor.Require(Roles.Customer, Roles.Driver);
        var ride = db.Set<Ride>().AsNoTracking().SingleOrDefault(r => r.Id == id) ?? throw Missing();
        var driver = db.Set<Driver>().AsNoTracking().SingleOrDefault(d => d.Id == ride.DriverId);
        if (actor.Role == Roles.Customer ? actor.Id != ride.CustomerId : driver?.UserId != actor.Id)
            throw Missing();
        var active = RideStates.IsActive(ride.Status);
        var assignment = db.Set<Assignment>().AsNoTracking()
            .Where(a => a.RideId == id && a.DriverId == ride.DriverId && (!active || a.EndedAt == null))
            .OrderByDescending(a => a.CreatedAt).ThenByDescending(a => a.Id).FirstOrDefault();
        if (driver == null || assignment == null || RideStates.IsActive(ride.Status) && assignment.EndedAt != null)
            throw new RuleException("CHAT_UNAVAILABLE", "Chat sẽ sẵn sàng khi tài xế nhận chuyến.");
        var peerId = actor.Role == Roles.Customer ? driver.UserId : ride.CustomerId;
        return (ride, assignment, db.Set<User>().AsNoTracking().Single(u => u.Id == peerId));
    }

    private static bool ChatCanSend(Ride ride, Assignment assignment) =>
        assignment.EndedAt == null && ride.Status is "ASSIGNED" or "DRIVER_ARRIVED" or "IN_PROGRESS";

    private static void RequireChatAssignment(string assignmentId, Assignment assignment)
    {
        if (assignmentId != assignment.Id)
            throw new RuleException("CHAT_ASSIGNMENT_CHANGED", "Tài xế đã thay đổi. Vui lòng mở lại cuộc trò chuyện.");
    }

    private static object ChatMessageView(RideChatMessage message, ISecrets secrets) => new
    {
        message.Id, message.AssignmentId, message.SenderId, message.Sequence,
        body = secrets.Unprotect(message.BodyProtected), message.CreatedAt
    };
}

public record SendRideMessage(string AssignmentId, string? Body);
