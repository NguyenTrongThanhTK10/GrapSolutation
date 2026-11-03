using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Api;

public static partial class Endpoints
{
    private static readonly string[] RequiredDocuments = ["IDENTITY", "DRIVING_LICENSE", "VEHICLE_REGISTRATION", "INSURANCE"];
    private static void MapFiles(RouteGroupBuilder auth)
    {
        auth.MapPost("/files/upload-intents", (UploadIntent body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            ctx.Actor().Require(Roles.Driver); if (body.ContentType is not ("image/jpeg" or "image/png") || body.Size is <= 0 or > 5_242_880 || body.Purpose != "DRIVER_DOCUMENT") throw new RuleException("INVALID_FILE", "Chỉ nhận ảnh JPEG/PNG tối đa 5 MB cho giấy tờ tài xế.", 422);
            var file = new PrivateFile { OwnerId = ctx.Actor().Id, ContentType = body.ContentType, Size = body.Size, Purpose = body.Purpose }; db.Add(file); return Task.FromResult<object?>(new { fileId = file.Id, uploadUrl = "/api/v1/files/" + file.Id + "/content", method = "PUT", file.ExpiresAt });
        }, status: 201));
        auth.MapPut("/files/{id}/content", async (string id, HttpContext ctx, GrapDbContext db, RideService service, IWebHostEnvironment env) =>
        {
            if (!env.IsDevelopment()) throw new RuleException("DEPENDENCY_UNAVAILABLE", "Cần adapter storage private đã được duyệt ở môi trường triển khai.", 503);
            var file = service.Find<PrivateFile>(id); if (file.OwnerId != ctx.Actor().Id) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy file.", 404);
            if (file.Status == "COMPLETE" || file.ExpiresAt <= DateTime.UtcNow) throw new RuleException("UPLOAD_EXPIRED", "Upload intent đã đóng hoặc hết hạn.");
            if (ctx.Request.ContentLength != file.Size || ctx.Request.ContentType != file.ContentType) throw new RuleException("INVALID_FILE", "Kích thước hoặc loại file không khớp upload intent.", 422);
            await using var memory = new MemoryStream(); var buffer = new byte[8192]; int read; while ((read = await ctx.Request.Body.ReadAsync(buffer, ctx.RequestAborted)) > 0) { if (memory.Length + read > file.Size) throw new RuleException("INVALID_FILE", "File quá lớn.", 422); await memory.WriteAsync(buffer.AsMemory(0, read), ctx.RequestAborted); }
            var bytes = memory.ToArray(); if (bytes.Length != file.Size || !IsImage(bytes, file.ContentType)) throw new RuleException("INVALID_FILE", "Nội dung ảnh không hợp lệ hoặc MIME bị giả mạo.", 422);
            var directory = Path.Combine(env.ContentRootPath, ".local", "private-files"); Directory.CreateDirectory(directory); var temp = Path.Combine(directory, Guid.NewGuid() + ".upload"); await File.WriteAllBytesAsync(temp, bytes, ctx.RequestAborted); try { File.Move(temp, Path.Combine(directory, file.Id), false); } catch (IOException) when (File.Exists(Path.Combine(directory, file.Id))) { File.Delete(temp); if (!File.ReadAllBytes(Path.Combine(directory, file.Id)).AsSpan().SequenceEqual(bytes)) throw new RuleException("UPLOAD_ALREADY_EXISTS", "File đã được tải lên. Tạo upload intent mới để thay thế."); }
            return Results.Ok(new { uploaded = true, fileId = file.Id });
        }).DisableAntiforgery();
        auth.MapPost("/files/{id}/complete", (string id, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, IWebHostEnvironment env) => Write(ctx, executor, secrets, new { id }, () =>
        {
            var file = service.Find<PrivateFile>(id); if (file.OwnerId != ctx.Actor().Id) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy file.", 404);
            var path = Path.Combine(env.ContentRootPath, ".local", "private-files", file.Id); if (!File.Exists(path) || file.ExpiresAt <= DateTime.UtcNow) throw new RuleException("UPLOAD_INCOMPLETE", "Chưa có file hợp lệ hoặc upload đã hết hạn.", 422);
            var bytes = File.ReadAllBytes(path); if (bytes.Length != file.Size || !IsImage(bytes, file.ContentType)) throw new RuleException("INVALID_FILE", "File không hợp lệ.", 422); file.Status = "COMPLETE"; return Task.FromResult<object?>(new { fileId = file.Id, file.Status });
        }));
        auth.MapGet("/files/{id}/content", (string id, HttpContext ctx, RideService service, GrapDbContext db, IWebHostEnvironment env) =>
        {
            var file = service.Find<PrivateFile>(id); var actor = ctx.Actor(); if (file.OwnerId != actor.Id) { actor.Require(Roles.Reviewer); var owner = service.Find<User>(file.OwnerId); actor.Scope(owner.ZoneId); }
            if (file.Status != "COMPLETE") throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy file.", 404); var path = Path.Combine(env.ContentRootPath, ".local", "private-files", file.Id); if (!File.Exists(path)) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy file.", 404);
            service.Audit(actor, "document.content.read", id, "ONBOARDING_REVIEW"); db.SaveChanges();
            ctx.Response.Headers.ContentDisposition = "attachment; filename=\"document" + (file.ContentType == "image/png" ? ".png" : ".jpg") + "\""; return Results.File(path, file.ContentType);
        });
        auth.MapGet("/drivers/me/documents", (HttpContext ctx, RideService service, GrapDbContext db) => { var driver = service.DriverFor(ctx.Actor()); return new { items = db.Set<DriverDocument>().Where(d => d.DriverId == driver.Id).OrderByDescending(d => d.CreatedAt).ToList(), requiredTypes = RequiredDocuments }; });
        auth.MapPost("/drivers/me/documents", (DocumentRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var driver = service.DriverFor(ctx.Actor());
            if (driver.ReviewStatus is not ("DRAFT" or "REJECTED")) throw new RuleException("APPLICATION_LOCKED", "Chỉ bổ sung giấy tờ vào hồ sơ nháp hoặc hồ sơ cần bổ sung.");
            var file = service.Find<PrivateFile>(body.FileId); if (file.OwnerId != ctx.Actor().Id || file.Status != "COMPLETE" || !RequiredDocuments.Contains(body.Type) || body.ExpiresAt <= DateTime.UtcNow) throw new RuleException("INVALID_DOCUMENT", "Giấy tờ hoặc file không hợp lệ.", 422);
            var version = db.Set<DriverDocument>().Where(d => d.DriverId == driver.Id && d.Type == body.Type).Select(d => (int?)d.Version).Max() ?? 0;
            var document = new DriverDocument { DriverId = driver.Id, Type = body.Type, FileId = file.Id, ExpiresAt = body.ExpiresAt, Version = version + 1 }; db.Add(document); driver.Version++; return Task.FromResult<object?>(document);
        }, status: 201));
        auth.MapPost("/drivers/me/application/submit", (VersionRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service, GrapDbContext db) => Write(ctx, executor, secrets, body, () =>
        {
            var driver = service.DriverFor(ctx.Actor()); if (driver.Version != body.ExpectedVersion || driver.ReviewStatus is not ("DRAFT" or "REJECTED")) throw new RuleException("VERSION_CONFLICT", "Hồ sơ đã thay đổi hoặc không ở trạng thái có thể nộp.");
            if (string.IsNullOrWhiteSpace(driver.Vehicle) || string.IsNullOrWhiteSpace(driver.Plate)) throw new RuleException("VEHICLE_REQUIRED", "Cần khai báo phương tiện.", 422);
            var latest = db.Set<DriverDocument>().Where(d => d.DriverId == driver.Id).ToList().GroupBy(d => d.Type).Select(g => g.OrderByDescending(d => d.Version).First()).ToList();
            if (RequiredDocuments.Any(type => !latest.Any(d => d.Type == type && d.Status != "REJECTED" && d.ExpiresAt > DateTime.UtcNow))) throw new RuleException("DOCUMENTS_REQUIRED", "Cần đủ giấy tờ còn hạn; giấy tờ bị từ chối phải được nộp lại.", 422);
            driver.ReviewStatus = "PENDING_REVIEW"; driver.Version++; return Task.FromResult<object?>(driver);
        }));
        auth.MapGet("/admin/drivers/{id}/documents", (string id, HttpContext ctx, RideService service, GrapDbContext db) => { ctx.Actor().Require(Roles.Reviewer); var d = service.Find<Driver>(id); ctx.Actor().Scope(d.ZoneId); return new { items = db.Set<DriverDocument>().Where(doc => doc.DriverId == id).OrderByDescending(doc => doc.CreatedAt).ToList(), requiredTypes = RequiredDocuments }; });
        auth.MapPost("/admin/driver-documents/{id}/review-decisions", (string id, ReviewRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service) => Write(ctx, executor, secrets, body, () =>
        {
            ctx.Actor().Require(Roles.Reviewer); var document = service.Find<DriverDocument>(id); var driver = service.Find<Driver>(document.DriverId); ctx.Actor().Scope(driver.ZoneId); if (document.Version != body.ExpectedVersion || document.Status != "PENDING_REVIEW" || body.Decision is not ("APPROVED" or "REJECTED")) throw new RuleException("VERSION_CONFLICT", "Phiên bản hoặc kết quả duyệt không hợp lệ."); RideService.RequireReason(body.ReasonCode); document.Status = body.Decision; document.ReviewReason = body.ReasonCode; service.Audit(ctx.Actor(), "document.review." + body.Decision, id, body.ReasonCode); return Task.FromResult<object?>(document);
        }));
    }
    private static bool IsImage(byte[] bytes, string contentType) => contentType == "image/png" ? bytes.Length > 24 && bytes.AsSpan(0, 8).SequenceEqual(new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 }) && bytes.AsSpan(12, 4).SequenceEqual("IHDR"u8) : bytes.Length > 4 && bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255 && bytes[^2] == 255 && bytes[^1] == 217;
}
public record UploadIntent(string ContentType, long Size, string Purpose);
public record DocumentRequest(string Type, string FileId, DateTime ExpiresAt);
