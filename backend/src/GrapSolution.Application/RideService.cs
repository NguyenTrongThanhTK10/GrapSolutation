using System.Text.Json;
using GrapSolution.Domain;
namespace GrapSolution.Application;

public sealed class RideService(IGrapStore db, IMapProvider maps, ISecrets secrets)
{
    public T Find<T>(string id) where T : Entity => db.Query<T>().SingleOrDefault(x => x.Id == id) ?? throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu.", 404);
    public Driver DriverFor(Actor actor) { actor.Require(Roles.Driver); return db.Query<Driver>().SingleOrDefault(d => d.UserId == actor.Id) ?? throw new RuleException("DRIVER_NOT_APPROVED", "Bạn cần hoàn tất hồ sơ tài xế.", 403); }
    public Ride AuthorizedRide(Actor actor, string id)
    {
        var ride = Find<Ride>(id); actor.Scope(ride.ZoneId);
        if (actor.Staff) { actor.Require(Roles.Dispatcher, Roles.Support, Roles.Operations, Roles.Finance, Roles.Approver); return ride; }
        if (actor.Role == Roles.Customer && ride.CustomerId == actor.Id) return ride;
        if (actor.Role == Roles.Driver && db.Query<Assignment>().Any(a => a.RideId == id && a.DriverId == DriverFor(actor).Id && (a.EndedAt == null || !RideStates.Active.Contains(ride.Status)))) return ride;
        throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy chuyến.", 404);
    }
    public object Snapshot(Actor actor, Ride ride)
    {
        var customer = Find<User>(ride.CustomerId); var driver = ride.DriverId == null ? null : Find<Driver>(ride.DriverId); var driverUser = driver == null ? null : Find<User>(driver.UserId); var payment = db.Query<Payment>().SingleOrDefault(p => p.RideId == ride.Id);
        var active = RideStates.IsActive(ride.Status);
        return new { rideId = ride.Id, rideCode = ride.Code, ride.Status, ride.Version, ride.ServiceTypeCode, ride.Pickup, ride.Dropoff, ride.PickupNote, ride.Fare, ride.CreatedAt, ride.ArrivedAt, ride.EndedAt, dispatchDeadlineAt = ride.DeadlineAt, customer = new { customer.Id, customer.Name, phone = Mask(customer.Phone) }, driver = driver == null ? null : new { driver.Id, name = driverUser!.Name, phone = Mask(driverUser.Phone), driver.Vehicle, driver.Color, driver.Plate, driver.Rating, latitude = active ? (double?)driver.Latitude : null, longitude = active ? (double?)driver.Longitude : null, locationAt = active ? driver.LocationAt : null, locationSequence = active ? (long?)driver.LocationSequence : null }, pickupPin = actor.Id == ride.CustomerId && active ? secrets.Unprotect(ride.CustomerPinProtected) : null, assignmentId = db.Query<Assignment>().SingleOrDefault(a => a.RideId == ride.Id && a.EndedAt == null)?.Id, payment = payment == null ? null : new { payment.Id, payment.Status, payment.PayableAmount, payment.PaidAmount, remainingAmount = payment.PayableAmount - payment.PaidAmount, payment.Currency }, serverTime = DateTime.UtcNow };
    }
    public static string Mask(string phone) => phone.Length > 6 ? phone[..3] + " ••• " + phone[^3..] : "•••";
    public void Audit(Actor actor, string action, string resource, string reason = "") => db.Add(new AuditLog { ActorId = actor.Id, ActorName = db.Query<User>().SingleOrDefault(u => u.Id == actor.Id)?.Name ?? "System", Action = action, ResourceId = resource, Reason = reason, ZoneId = actor.ZoneId, TraceId = System.Diagnostics.Activity.Current?.TraceId.ToString() ?? Guid.NewGuid().ToString("N") });
    private void Event(Ride ride, string type, string actor, string? reason = null)
    {
        db.Add(new RideEvent { RideId = ride.Id, Sequence = ride.Version, EventType = type, ActorId = actor, Reason = reason });
        db.Add(new OutboxMessage { EventType = "ride.status.changed", AggregateId = ride.Id, AggregateVersion = ride.Version, Payload = JsonSerializer.Serialize(new { rideId = ride.Id, ride.Status, ride.Version }) });
        db.Add(new Notification { UserId = ride.CustomerId, Title = "Cập nhật chuyến " + ride.Code, Body = type, EntityId = ride.Id });
        if (ride.DriverId != null) db.Add(new Notification { UserId = Find<Driver>(ride.DriverId).UserId, Title = "Cập nhật chuyến " + ride.Code, Body = type, EntityId = ride.Id });
    }
    public async Task<Quote> CreateQuote(Actor actor, QuoteRequest request, CancellationToken ct)
    {
        actor.Require(Roles.Customer); request.Pickup.Validate(); request.Dropoff.Validate();
        if (request.PaymentMethodType != "CASH") throw new RuleException("PAYMENT_METHOD_UNAVAILABLE", "Giai đoạn P0 hỗ trợ tiền mặt.", 422);
        if (request.Pickup.DistanceTo(request.Dropoff) < 50) throw new RuleException("INVALID_COORDINATES", "Điểm đón và điểm đến phải khác nhau.", 400);
        var zone = db.Query<ServiceZone>().ToList().FirstOrDefault(z => z.Active && Contains(z.PolygonJson, request.Pickup) && Contains(z.PolygonJson, request.Dropoff)) ?? throw new RuleException("OUTSIDE_SERVICE_ZONE", "Địa điểm nằm ngoài vùng phục vụ.", 422);
        var now = DateTime.UtcNow; var policy = db.Query<FarePolicy>().Where(p => p.ZoneId == zone.Id && p.ServiceTypeCode == request.ServiceTypeCode && p.Status == "PUBLISHED" && p.EffectiveFrom <= now).OrderByDescending(p => p.Version).FirstOrDefault() ?? throw new RuleException("SERVICE_UNAVAILABLE", "Dịch vụ chưa được cấu hình trong vùng này.", 422);
        var route = await maps.Route(request.Pickup, request.Dropoff, request.ServiceTypeCode, ct);
        var quote = new Quote { CustomerId = actor.Id, Pickup = request.Pickup, Dropoff = request.Dropoff, ServiceTypeCode = request.ServiceTypeCode, ZoneId = zone.Id, FarePolicyId = policy.Id, FarePolicyVersion = policy.Version, Fare = policy.Calculate(route.DistanceMeters, route.DurationSeconds), DistanceMeters = route.DistanceMeters, DurationSeconds = route.DurationSeconds, RouteSource = route.Source, RouteGeometry = route.Geometry };
        db.Add(quote); return quote;
    }
    public static bool Contains(string polygon, GeoPoint point)
    {
        var vertices = JsonSerializer.Deserialize<double[][]>(polygon) ?? []; bool inside = false;
        for (int i = 0, j = vertices.Length - 1; i < vertices.Length; j = i++) { var a = vertices[i]; var b = vertices[j]; if ((a[1] > point.Latitude) != (b[1] > point.Latitude) && point.Longitude < (b[0] - a[0]) * (point.Latitude - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside; }
        return inside;
    }
    public Ride CreateRide(Actor actor, RideRequest request)
    {
        actor.Require(Roles.Customer); var quote = Find<Quote>(request.QuoteId);
        if (quote.CustomerId != actor.Id) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy báo giá.", 404);
        if (quote.ConsumedRideId != null) throw new RuleException("QUOTE_ALREADY_USED", "Báo giá đã được sử dụng.");
        if (quote.ExpiresAt <= DateTime.UtcNow) throw new RuleException("QUOTE_EXPIRED", "Báo giá đã hết hạn, vui lòng lấy giá mới.");
        if (db.Query<Ride>().Any(r => r.CustomerId == actor.Id && RideStates.Active.Contains(r.Status))) throw new RuleException("ACTIVE_RIDE_EXISTS", "Bạn đã có chuyến đang hoạt động.");
        var pin = System.Security.Cryptography.RandomNumberGenerator.GetInt32(1000, 10000).ToString();
        var ride = new Ride { CustomerId = actor.Id, QuoteId = quote.Id, Pickup = quote.Pickup, Dropoff = quote.Dropoff, Fare = quote.Fare, ZoneId = quote.ZoneId, ServiceTypeCode = quote.ServiceTypeCode, PickupNote = request.PickupNote ?? "", PinHmac = secrets.Hmac(pin), CustomerPinProtected = secrets.Protect(pin) };
        quote.ConsumedRideId = ride.Id; db.Add(ride); Event(ride, "Đã tạo yêu cầu tìm tài xế", actor.Id); return ride;
    }
    private IQueryable<Driver> EligibleDrivers(DateTime now) => db.Query<Driver>().Where(driver =>
        driver.ReviewStatus == "APPROVED" && driver.Online && driver.ActiveSessionId != null &&
        db.Query<User>().Any(user => user.Id == driver.UserId && user.Status == "ACTIVE") &&
        db.Query<Session>().Any(session => session.Id == driver.ActiveSessionId && session.RevokedAt == null && session.ExpiresAt > now) &&
        driver.DocumentsExpireAt > now && driver.HeartbeatAt > now.AddSeconds(-30) && driver.LocationAt > now.AddSeconds(-30) &&
        driver.Accuracy <= 100 && !db.Query<Assignment>().Any(a => a.DriverId == driver.Id && a.EndedAt == null));
    private bool Eligible(Driver driver, DateTime now) => EligibleDrivers(now).Any(d => d.Id == driver.Id);
    public NearbyServices Nearby(Actor actor, GeoPoint pickup)
    {
        actor.Require(Roles.Customer); pickup.Validate();
        var now = DateTime.UtcNow;
        var zone = db.Query<ServiceZone>().ToList().FirstOrDefault(z => z.Active && Contains(z.PolygonJson, pickup));
        var counts = new Dictionary<string, int>();
        if (zone != null)
        {
            // Filter eligibility in SQL; project only fields needed for aggregate distance counts.
            counts = EligibleDrivers(now).Where(d => d.ZoneId == zone.Id &&
                    !db.Query<Offer>().Any(o => o.DriverId == d.Id && o.Status == "OPEN" && o.ExpiresAt > now))
                .Select(d => new { d.ServiceTypeCode, d.Latitude, d.Longitude }).ToList()
                .Where(d => pickup.DistanceTo(new(d.Latitude, d.Longitude, "")) <= 3000)
                .GroupBy(d => d.ServiceTypeCode).ToDictionary(g => g.Key, g => g.Count());
        }
        return new(zone != null, 3000, now, new[] { "BIKE", "CAR_4", "CAR_7" }
            .Select(code => new NearbyService(code, counts.GetValueOrDefault(code))).ToList());
    }
    public async Task Dispatch(CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        foreach (var offer in db.Query<Offer>().Where(o => o.Status == "OPEN" && o.ExpiresAt <= now).ToList()) { offer.Status = "EXPIRED"; offer.Version++; }
        await db.Save(ct); // Close expired slots before reusing filtered unique indexes.
        foreach (var ride in db.Query<Ride>().Where(r => r.Status == "SEARCHING").ToList())
        {
            if (ride.DeadlineAt <= now) { CloseOffers(ride.Id); ride.Change("NO_DRIVER"); Event(ride, "Không tìm được tài xế trong thời gian cho phép", "system"); continue; }
            var open = db.Query<Offer>().Where(o => o.RideId == ride.Id && o.Status == "OPEN").ToList().Any(o => o.Status == "OPEN"); if (open) continue;
            var tried = db.Query<Offer>().Where(o => o.RideId == ride.Id).Select(o => o.DriverId).ToHashSet();
            var reserved = db.Query<Offer>().Where(o => o.Status == "OPEN").ToList().Where(o => o.Status == "OPEN").Select(o => o.DriverId).ToHashSet();
            var radius = (now - ride.CreatedAt).TotalSeconds < 30 ? 1000 : (now - ride.CreatedAt).TotalSeconds < 60 ? 3000 : 5000;
            var driver = EligibleDrivers(now).Where(d => d.ServiceTypeCode == ride.ServiceTypeCode && d.ZoneId == ride.ZoneId).ToList().Where(d => !tried.Contains(d.Id) && !reserved.Contains(d.Id)).OrderBy(d => ride.Pickup.DistanceTo(new(d.Latitude, d.Longitude, ""))).FirstOrDefault(d => ride.Pickup.DistanceTo(new(d.Latitude, d.Longitude, "")) <= radius);
            if (driver == null) continue;
            var next = new Offer { RideId = ride.Id, DriverId = driver.Id }; db.Add(next);
            db.Add(new Notification { UserId = driver.UserId, Kind = "offer", EntityId = next.Id, Title = "Có lời mời chuyến mới", Body = "Mở ứng dụng để xem lời mời còn hiệu lực." });
            db.Add(new OutboxMessage { EventType = "driver.offer.created", AggregateId = driver.UserId, Payload = JsonSerializer.Serialize(new { offerId = next.Id, rideId = ride.Id, next.ExpiresAt }) });
            await db.Save(ct);
        }
    }
    public Ride Accept(Actor actor, string offerId, int expectedVersion)
    {
        var driver = DriverFor(actor); var offer = Find<Offer>(offerId); if (offer.DriverId != driver.Id) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy lời mời.", 404);
        if (driver.ActiveSessionId != actor.SessionId) throw new RuleException("SESSION_EXPIRED", "Thiết bị không còn quyền nhận chuyến.", 403);
        if (offer.Status != "OPEN" || offer.ExpiresAt <= DateTime.UtcNow) throw new RuleException("OFFER_EXPIRED", "Lời mời đã đóng hoặc hết hạn.");
        if (offer.Version != expectedVersion) throw new RuleException("VERSION_CONFLICT", "Lời mời đã thay đổi.", 409, offer.Version);
        var ride = Find<Ride>(offer.RideId); RideStates.Require(ride.Status, "SEARCHING");
        if (!Eligible(driver, DateTime.UtcNow)) throw new RuleException("DRIVER_NOT_AVAILABLE", "Tài xế không đủ điều kiện nhận chuyến.");
        offer.Status = "ACCEPTED"; offer.Version++; ride.DriverId = driver.Id; ride.Change("ASSIGNED");
        db.Add(new Assignment { RideId = ride.Id, DriverId = driver.Id, VehicleSnapshot = JsonSerializer.Serialize(new { driver.Vehicle, driver.Plate, driver.Color }) }); Event(ride, "Tài xế đã nhận chuyến", actor.Id); return ride;
    }
    public void Reject(Actor actor, string id) { var driver = DriverFor(actor); var offer = Find<Offer>(id); if (offer.DriverId != driver.Id) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy lời mời.", 404); if (offer.Status == "OPEN") { offer.Status = "REJECTED"; offer.Version++; } }
    public Ride Command(Actor actor, string id, string command, RideCommand request)
    {
        var ride = AuthorizedRide(actor, id); ride.CheckVersion(request.ExpectedVersion);
        var isDriver = actor.Role == Roles.Driver && ride.DriverId == DriverFor(actor).Id;
        if (command is "arrive" or "start" or "complete" or "release-assignment" or "no-show") { if (!isDriver || !db.Query<Assignment>().Any(a => a.RideId == id && a.DriverId == ride.DriverId && a.EndedAt == null)) throw new RuleException("FORBIDDEN", "Chỉ tài xế hiện hành được thao tác.", 403); }
        switch (command)
        {
            case "arrive": RideStates.Require(ride.Status, "ASSIGNED"); ValidateLocation(request.Location, ride.Pickup, 200); ride.ArrivedAt = DateTime.UtcNow; ride.Change("DRIVER_ARRIVED"); break;
            case "start":
                RideStates.Require(ride.Status, "DRIVER_ARRIVED");
                if (ride.PinAttempts >= 5) throw new RuleException("PIN_LOCKED", "Đã vượt số lần nhập PIN. Vui lòng liên hệ hỗ trợ.", 422);
                if (request.PickupPin == null || !System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(System.Text.Encoding.UTF8.GetBytes(secrets.Hmac(request.PickupPin)), System.Text.Encoding.UTF8.GetBytes(ride.PinHmac))) { ride.PinAttempts++; throw new RuleException("PIN_INVALID", "Mã PIN không đúng.", 422, persist: true); }
                ride.Change("IN_PROGRESS"); break;
            case "complete":
            case "end-early":
                RideStates.Require(ride.Status, "IN_PROGRESS"); if (command == "end-early") { actor.Require(Roles.Operations); RequireReason(request.ReasonCode); } else { ValidateLocation(request.Location, request.CompletionType == "EARLY" ? null : ride.Dropoff, 300); if (request.CompletionType == "EARLY") RequireReason(request.ReasonCode); }
                ride.Change("COMPLETED"); Release(ride); db.Add(new Payment { RideId = id, DriverId = ride.DriverId!, PayableAmount = ride.Fare.CustomerPayable });
                Post(new Journal { OperationKey = id + ":entitlement", RideId = id, Description = "Ghi nhận nghĩa vụ chuyến " + ride.Code, Entries = [new() { Account = "CUSTOMER_RECEIVABLE", OwnerId = ride.CustomerId, Debit = ride.Fare.CustomerPayable }, new() { Account = "DRIVER_PAYABLE", OwnerId = ride.DriverId!, Credit = ride.Fare.GrossFare - ride.Fare.PlatformCommission }, new() { Account = "PLATFORM_FEES", Credit = ride.Fare.PlatformCommission }] }); break;
            case "cancel":
                if (actor.Id != ride.CustomerId) actor.Require(Roles.Dispatcher, Roles.Operations); RideStates.Require(ride.Status, "SEARCHING", "ASSIGNED", "DRIVER_ARRIVED"); RequireReason(request.ReasonCode); ride.Change("CANCELED"); CloseOffers(id); Release(ride); break;
            case "no-show": RideStates.Require(ride.Status, "DRIVER_ARRIVED"); if (ride.ArrivedAt == null || ride.ArrivedAt > DateTime.UtcNow.AddMinutes(-5)) throw new RuleException("WAIT_TIME_NOT_MET", "Cần chờ ít nhất 5 phút."); if (!db.Query<RideContactAttempt>().Any(a => a.RideId == id && a.DriverId == ride.DriverId && a.CreatedAt >= ride.ArrivedAt)) throw new RuleException("CONTACT_ATTEMPT_REQUIRED", "Cần ghi nhận đã thử liên hệ khách sau khi đến điểm đón.", 422); RequireReason(request.ReasonCode); ride.Change("CANCELED"); Release(ride); break;
            case "release-assignment":
            case "reassign":
                if (command == "reassign") actor.Require(Roles.Dispatcher, Roles.Operations); RideStates.Require(ride.Status, "ASSIGNED", "DRIVER_ARRIVED"); RequireReason(request.ReasonCode); Release(ride); CloseOffers(id); ride.DriverId = null; ride.ArrivedAt = null; ride.PinAttempts = 0;
                var pin = System.Security.Cryptography.RandomNumberGenerator.GetInt32(1000, 10000).ToString(); ride.PinHmac = secrets.Hmac(pin); ride.CustomerPinProtected = secrets.Protect(pin); ride.Change("SEARCHING"); break;
            default: throw new RuleException("RESOURCE_NOT_FOUND", "Không có lệnh này.", 404);
        }
        Event(ride, command, actor.Id, request.ReasonCode); if (actor.Staff) Audit(actor, "ride." + command, id, request.ReasonCode ?? ""); return ride;
    }
    private static void ValidateLocation(LocationEvidence? location, GeoPoint? target, int threshold)
    {
        if (location == null || location.AccuracyMeters is <= 0 or > 100 || Math.Abs((DateTime.UtcNow - location.RecordedAt).TotalSeconds) > 30) throw new RuleException("LOCATION_NOT_TRUSTED", "Cần vị trí mới trong 30 giây, sai số tối đa 100 m.", 422);
        var point = new GeoPoint(location.Latitude, location.Longitude, "Vị trí xác nhận"); point.Validate(); if (target != null && point.DistanceTo(target) > threshold) throw new RuleException("LOCATION_NOT_TRUSTED", "Vị trí quá xa điểm xác nhận. Vui lòng cập nhật hoặc liên hệ hỗ trợ.", 422);
    }
    public static void RequireReason(string? reason) { if (string.IsNullOrWhiteSpace(reason) || reason.Length < 3 || reason.Length > 1000) throw new RuleException("VALIDATION_ERROR", "Cần lý do từ 3 đến 1.000 ký tự.", 400); }
    private void Release(Ride ride) { foreach (var assignment in db.Query<Assignment>().Where(a => a.RideId == ride.Id && a.EndedAt == null).ToList()) { assignment.EndedAt = DateTime.UtcNow; assignment.EndReason = ride.Status; } if (ride.DriverId != null) { var driver = Find<Driver>(ride.DriverId); if (driver.OfflineAfterRide) { driver.Online = false; driver.OfflineAfterRide = false; driver.Version++; } } }
    private void CloseOffers(string rideId) { foreach (var o in db.Query<Offer>().Where(o => o.RideId == rideId && o.Status == "OPEN").ToList()) { o.Status = "REVOKED"; o.Version++; } }
    public void Post(Journal journal) { journal.Validate(); if (db.Query<Journal>().Any(j => j.OperationKey == journal.OperationKey)) return; foreach (var entry in journal.Entries) entry.JournalId = journal.Id; db.Add(journal); }
    public Payment Collect(Actor actor, string id, CashRequest request)
    {
        var payment = Find<Payment>(id); var ride = AuthorizedRide(actor, payment.RideId);
        if (actor.Role == Roles.Driver) { if (DriverFor(actor).Id != payment.DriverId) throw new RuleException("FORBIDDEN", "Không có quyền ghi nhận khoản thu.", 403); } else actor.Require(Roles.Finance);
        RideStates.Require(ride.Status, "COMPLETED");
        var existing = db.Query<CashCollection>().SingleOrDefault(c => c.OperationId == request.OperationId); if (existing != null) { if (existing.PaymentId != id || existing.Amount != request.CollectedAmount) throw new RuleException("IDEMPOTENCY_CONFLICT", "Operation ID đã dùng với dữ liệu khác."); return payment; }
        RequireReason(request.ReasonCode);
        if (request.Currency != "VND" || request.CollectedAmount < 0 || request.CollectedAmount > payment.PayableAmount - payment.PaidAmount || string.IsNullOrWhiteSpace(request.OperationId)) throw new RuleException("INVALID_AMOUNT", "Số tiền không hợp lệ hoặc vượt số còn phải thu.", 422);
        db.Add(new CashCollection { PaymentId = id, DriverId = payment.DriverId, Amount = request.CollectedAmount, OperationId = request.OperationId, Reason = request.ReasonCode }); payment.PaidAmount += request.CollectedAmount; payment.Status = payment.PaidAmount == payment.PayableAmount ? "SUCCEEDED" : "PENDING";
        if (request.CollectedAmount > 0) Post(new Journal { OperationKey = "cash:" + request.OperationId, RideId = ride.Id, Description = "Thu tiền mặt · " + ride.Code, Entries = [new() { Account = "DRIVER_PAYABLE", OwnerId = payment.DriverId, Debit = request.CollectedAmount }, new() { Account = "CUSTOMER_RECEIVABLE", OwnerId = ride.CustomerId, Credit = request.CollectedAmount }] });
        db.Add(new Notification { UserId = ride.CustomerId, EntityId = ride.Id, Title = "Cập nhật thanh toán", Body = "Khoản thu tiền mặt của chuyến đã được cập nhật." });
        Audit(actor, "payment.cash-collected", id, request.ReasonCode); return payment;
    }
    public object Balance(string driverId)
    {
        var entries = db.Query<LedgerEntry>().Where(e => e.OwnerId == driverId && e.Account == "DRIVER_PAYABLE").ToList(); var net = entries.Sum(e => e.Credit - e.Debit);
        var unsettled = db.Query<Payment>().Where(p => p.DriverId == driverId && p.Status == "PENDING").ToList();
        var pendingEntitlement = unsettled.Sum(p => { var ride = Find<Ride>(p.RideId); return Math.Max(0, ride.Fare.GrossFare - ride.Fare.PlatformCommission - p.PaidAmount); });
        var pending = Math.Min(Math.Max(0, net), pendingEntitlement);
        return new { pending, available = Math.Max(0, net - pending), held = 0, debt = Math.Max(0, -net), currency = "VND", updatedAt = DateTime.UtcNow };
    }
}
