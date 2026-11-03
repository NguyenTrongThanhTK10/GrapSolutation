using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
namespace GrapSolution.Api;
public static partial class Endpoints
{
    private static string[] DeletionBlockers(string userId, GrapDbContext db)
    {
        var blockers = new List<string>(); var driver = db.Set<Driver>().SingleOrDefault(d => d.UserId == userId); var driverId = driver?.Id ?? "";
        if (db.Set<Ride>().Any(r => (r.CustomerId == userId || r.DriverId == driverId) && RideStates.Active.Contains(r.Status))) blockers.Add("ACTIVE_RIDE");
        if (db.Set<Payment>().Any(p => p.PaidAmount < p.PayableAmount && db.Set<Ride>().Any(r => r.Id == p.RideId && r.CustomerId == userId))) blockers.Add("OUTSTANDING_PAYMENT");
        if (driver != null)
        {
            var entries = db.Set<LedgerEntry>().Where(e => e.OwnerId == driverId && e.Account == "DRIVER_PAYABLE").ToList();
            if (entries.Sum(e => e.Credit - e.Debit) != 0) blockers.Add("DRIVER_BALANCE_PENDING");
        }
        return blockers.ToArray();
    }
    private static object DeletionView(AccountDeletionRequest request, GrapDbContext db) => new { request.Id, request.Status, request.Reason, request.ReviewNote, request.Version, request.TicketId, request.CreatedAt, blockers = DeletionBlockers(request.UserId, db), dataDeleted = false };
    private static void MapAccountDeletion(RouteGroupBuilder auth)
    {
        auth.MapGet("/me/account-deletion-requests", (HttpContext ctx, GrapDbContext db) =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
            return new { items = db.Set<AccountDeletionRequest>().Where(r => r.UserId == actor.Id).OrderByDescending(r => r.CreatedAt).Take(20).ToList().Select(r => DeletionView(r, db)) };
        });
        auth.MapPost("/me/account-deletion-requests", (DeletionRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); RideService.RequireReason(body.Reason);
            if (db.Set<AccountDeletionRequest>().Any(r => r.UserId == actor.Id && AccountDeletionRequest.OpenStates.Contains(r.Status))) throw new RuleException("DELETION_REQUEST_EXISTS", "Bạn đã có yêu cầu đang được xử lý.");
            var blockers = DeletionBlockers(actor.Id, db); var ticket = new SupportTicket { RequesterId = actor.Id, ZoneId = actor.ZoneId, Subject = "Yêu cầu xóa tài khoản", Category = "ACCOUNT_DELETION" };
            var request = new AccountDeletionRequest { UserId = actor.Id, ZoneId = actor.ZoneId, Reason = body.Reason.Trim(), TicketId = ticket.Id, Status = blockers.Length > 0 ? "BLOCKED_OBLIGATIONS" : "REQUESTED" };
            db.Add(ticket); db.Add(new TicketMessage { TicketId = ticket.Id, AuthorId = actor.Id, Body = body.Reason.Trim() }); db.Add(request); service.Audit(actor, "privacy.deletion.requested", request.Id);
            return Task.FromResult<object?>(DeletionView(request, db));
        }, true, 201));
        auth.MapPost("/me/account-deletion-requests/{id}/recheck", (string id, VersionRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var request = service.Find<AccountDeletionRequest>(id); if (request.UserId != actor.Id) throw Missing();
            if (request.Version != body.ExpectedVersion || !AccountDeletionRequest.OpenStates.Contains(request.Status)) throw new RuleException("VERSION_CONFLICT", "Yêu cầu đã thay đổi.", 409, request.Version);
            var blockers = DeletionBlockers(actor.Id, db); request.Status = blockers.Length > 0 ? "BLOCKED_OBLIGATIONS" : request.Status == "BLOCKED_OBLIGATIONS" ? "REQUESTED" : request.Status; request.Version++; service.Audit(actor, "privacy.deletion.rechecked", id); return Task.FromResult<object?>(DeletionView(request, db));
        }, true));
        auth.MapPost("/me/account-deletion-requests/{id}/cancel", (string id, VersionRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var request = service.Find<AccountDeletionRequest>(id); if (request.UserId != actor.Id) throw Missing();
            if (request.Version != body.ExpectedVersion || !AccountDeletionRequest.OpenStates.Contains(request.Status)) throw new RuleException("VERSION_CONFLICT", "Yêu cầu đã thay đổi.", 409, request.Version);
            request.Status = "WITHDRAWN"; request.WithdrawnAt = DateTime.UtcNow; request.Version++; service.Audit(actor, "privacy.deletion.withdrawn", id); return Task.FromResult<object?>(DeletionView(request, db));
        }, true));
        auth.MapGet("/admin/account-deletion-requests", (HttpContext ctx, GrapDbContext db) =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Security);
            return new { items = db.Set<AccountDeletionRequest>().Where(r => r.ZoneId == actor.ZoneId).OrderByDescending(r => r.CreatedAt).Take(100).ToList().Select(r => DeletionView(r, db)) };
        });
        auth.MapPost("/admin/account-deletion-requests/{id}/review", (string id, DeletionReviewRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Security); var request = service.Find<AccountDeletionRequest>(id); actor.Scope(request.ZoneId); RideService.RequireReason(body.Reason);
            if (request.Version != body.ExpectedVersion || !AccountDeletionRequest.OpenStates.Contains(request.Status)) throw new RuleException("VERSION_CONFLICT", "Yêu cầu đã thay đổi.", 409, request.Version);
            if (body.Decision is not ("IN_REVIEW" or "NEEDS_INFORMATION" or "REJECTED")) throw new RuleException("VALIDATION_ERROR", "Chỉ tiếp nhận, yêu cầu bổ sung hoặc từ chối. Chưa bật xóa dữ liệu tự động.", 400);
            if (body.Decision == "IN_REVIEW" && DeletionBlockers(request.UserId, db).Length > 0) throw new RuleException("DELETION_OBLIGATIONS_PENDING", "Cần xử lý nghĩa vụ còn lại trước khi tiếp nhận.", 422);
            request.Status = body.Decision; request.ReviewerId = actor.Id; request.ReviewNote = body.Reason; request.Version++;
            db.Add(new TicketMessage { TicketId = request.TicketId, AuthorId = actor.Id, Body = body.Reason }); service.Audit(actor, "privacy.deletion.reviewed", id); return Task.FromResult<object?>(DeletionView(request, db));
        }, true));
    }
}
public record DeletionRequest(string Reason);
public record DeletionReviewRequest(int ExpectedVersion, string Decision, string Reason);
