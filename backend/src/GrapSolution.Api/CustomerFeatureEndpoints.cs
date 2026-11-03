using System.Text.RegularExpressions;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Api;
public static partial class Endpoints
{
    private static void MapCustomerFeatures(RouteGroupBuilder auth)
    {
        auth.MapGet("/customers/me/saved-places", (HttpContext ctx, GrapDbContext db) =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer);
            return new { items = db.Set<SavedPlace>().Where(p => p.CustomerId == actor.Id && p.DeletedAt == null).OrderBy(p => p.Label).ToList() };
        });
        auth.MapPost("/customers/me/saved-places", (SavedPlaceRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, GrapDbContext db, RideService service) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer); ValidateSavedPlace(body);
            if (db.Set<SavedPlace>().Count(p => p.CustomerId == actor.Id && p.DeletedAt == null) >= 20) throw new RuleException("SAVED_PLACES_LIMIT", "Bạn có thể lưu tối đa 20 địa chỉ.", 422);
            var key = body.Label.Trim().ToUpperInvariant();
            if (db.Set<SavedPlace>().Any(p => p.CustomerId == actor.Id && p.LabelKey == key && p.DeletedAt == null)) throw new RuleException("PLACE_LABEL_EXISTS", "Tên địa chỉ này đã được sử dụng.");
            var place = new SavedPlace { CustomerId = actor.Id, Label = body.Label.Trim(), LabelKey = key, Address = body.Point.Address.Trim(), Latitude = body.Point.Latitude, Longitude = body.Point.Longitude, Note = body.Note?.Trim() ?? "" }; db.Add(place); service.Audit(actor, "place.saved", place.Id);
            return Task.FromResult<object?>(place);
        }, true, 201));
        auth.MapPatch("/customers/me/saved-places/{id}", (string id, SavedPlaceRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, GrapDbContext db, RideService service) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer); var place = service.Find<SavedPlace>(id);
            if (place.CustomerId != actor.Id || place.DeletedAt != null) throw Missing();
            if (body.ExpectedVersion != place.Version) throw new RuleException("VERSION_CONFLICT", "Địa chỉ đã thay đổi.", 409, place.Version);
            ValidateSavedPlace(body); var key = body.Label.Trim().ToUpperInvariant();
            if (db.Set<SavedPlace>().Any(p => p.CustomerId == actor.Id && p.Id != id && p.LabelKey == key && p.DeletedAt == null)) throw new RuleException("PLACE_LABEL_EXISTS", "Tên địa chỉ này đã được sử dụng.");
            place.Label = body.Label.Trim(); place.LabelKey = key; place.Address = body.Point.Address.Trim(); place.Latitude = body.Point.Latitude; place.Longitude = body.Point.Longitude; place.Note = body.Note?.Trim() ?? ""; place.Version++; service.Audit(actor, "place.updated", id);
            return Task.FromResult<object?>(place);
        }));
        auth.MapDelete("/customers/me/saved-places/{id}", (string id, int expectedVersion, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service) => Write(ctx, executor, secrets, new { id, expectedVersion }, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer); var place = service.Find<SavedPlace>(id);
            if (place.CustomerId != actor.Id) throw Missing();
            if (place.DeletedAt != null) return Task.FromResult<object?>(new { success = true });
            if (place.Version != expectedVersion) throw new RuleException("VERSION_CONFLICT", "Địa chỉ đã thay đổi.", 409, place.Version);
            place.DeletedAt = DateTime.UtcNow; place.Label = ""; place.LabelKey = ""; place.Address = ""; place.Note = ""; place.Latitude = 0; place.Longitude = 0; place.Version++; service.Audit(actor, "place.deleted", id); return Task.FromResult<object?>(new { success = true });
        }));
        auth.MapGet("/me/trusted-contacts", (HttpContext ctx, GrapDbContext db, ISecrets secrets) =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver);
            return new { items = db.Set<TrustedContact>().Where(c => c.UserId == actor.Id && c.DeletedAt == null).OrderBy(c => c.CreatedAt).ToList().Select(c => ContactView(c, secrets)) };
        });
        auth.MapPost("/me/trusted-contacts", (TrustedContactRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, GrapDbContext db, RideService service) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var phone = ValidateContact(body);
            if (db.Set<TrustedContact>().Count(c => c.UserId == actor.Id && c.DeletedAt == null) >= 5) throw new RuleException("CONTACTS_LIMIT", "Tối đa 5 liên hệ tin cậy.", 422);
            var contact = new TrustedContact { UserId = actor.Id, Name = body.Name.Trim(), PhoneProtected = secrets.Protect(phone), ConsentedAt = DateTime.UtcNow }; db.Add(contact); service.Audit(actor, "trusted-contact.created", contact.Id); return Task.FromResult<object?>(ContactView(contact, secrets));
        }, true, 201));
        auth.MapPatch("/me/trusted-contacts/{id}", (string id, TrustedContactRequest body, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service) => Write(ctx, executor, secrets, body, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var contact = service.Find<TrustedContact>(id);
            if (contact.UserId != actor.Id || contact.DeletedAt != null) throw Missing();
            if (body.ExpectedVersion != contact.Version) throw new RuleException("VERSION_CONFLICT", "Liên hệ đã thay đổi.", 409, contact.Version);
            var phone = ValidateContact(body); contact.Name = body.Name.Trim(); contact.PhoneProtected = secrets.Protect(phone); contact.ConsentedAt = DateTime.UtcNow; contact.Version++; service.Audit(actor, "trusted-contact.updated", id); return Task.FromResult<object?>(ContactView(contact, secrets));
        }));
        auth.MapDelete("/me/trusted-contacts/{id}", (string id, int expectedVersion, HttpContext ctx, AtomicExecutor executor, ISecrets secrets, RideService service) => Write(ctx, executor, secrets, new { id, expectedVersion }, () =>
        {
            var actor = ctx.Actor(); actor.Require(Roles.Customer, Roles.Driver); var contact = service.Find<TrustedContact>(id);
            if (contact.UserId != actor.Id) throw Missing();
            if (contact.DeletedAt != null) return Task.FromResult<object?>(new { success = true });
            if (contact.Version != expectedVersion) throw new RuleException("VERSION_CONFLICT", "Liên hệ đã thay đổi.", 409, contact.Version);
            contact.DeletedAt = DateTime.UtcNow; contact.PhoneProtected = ""; contact.Name = ""; contact.Version++; service.Audit(actor, "trusted-contact.deleted", id); return Task.FromResult<object?>(new { success = true });
        }));
        MapAccountDeletion(auth);
    }
    private static void ValidateSavedPlace(SavedPlaceRequest body)
    {
        if (body.Point == null || string.IsNullOrWhiteSpace(body.Label) || body.Label.Trim().Length > 60 || body.Note?.Length > 500) throw new RuleException("VALIDATION_ERROR", "Tên địa chỉ cần từ 1–60 ký tự; ghi chú tối đa 500 ký tự.", 400); body.Point.Validate();
    }
    private static string ValidateContact(TrustedContactRequest body)
    {
        if (!body.ConsentAccepted) throw new RuleException("CONTACT_CONSENT_REQUIRED", "Cần xác nhận đã có sự đồng ý của người liên hệ.", 422);
        var phone = body.Phone?.Trim().Replace(" ", "").Replace("-", "") ?? ""; if (phone.StartsWith('0')) phone = "+84" + phone[1..];
        if (string.IsNullOrWhiteSpace(body.Name) || body.Name.Trim().Length > 100 || !Regex.IsMatch(phone, @"^\+[1-9]\d{8,14}$")) throw new RuleException("VALIDATION_ERROR", "Họ tên hoặc số điện thoại liên hệ chưa hợp lệ.", 400); return phone;
    }
    private static object ContactView(TrustedContact contact, ISecrets secrets) => new { contact.Id, contact.Name, phone = secrets.Unprotect(contact.PhoneProtected), contact.Version, contact.ConsentedAt };
    private static RuleException Missing() => new("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu.", 404);
}
public record SavedPlaceRequest(string Label, GeoPoint Point, string? Note = null, int? ExpectedVersion = null);
public record TrustedContactRequest(string Name, string Phone, bool ConsentAccepted, int? ExpectedVersion = null);
