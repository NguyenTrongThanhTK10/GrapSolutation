using GrapSolution.Domain;
namespace GrapSolution.Application;
public interface IGrapStore { IQueryable<T> Query<T>() where T : Entity; void Add<T>(T entity) where T : Entity; Task Save(CancellationToken ct = default); }
public record Actor(string Id, string Role, string ZoneId, string SessionId)
{
    public bool Staff => Roles.Staff.Contains(Role);
    public void Require(params string[] roles) { if (!roles.Contains(Role)) throw new RuleException("FORBIDDEN", "Bạn không có quyền thực hiện thao tác này.", 403); }
    public void Scope(string zone) { if (Staff && ZoneId != zone) throw new RuleException("RESOURCE_NOT_FOUND", "Không tìm thấy dữ liệu.", 404); }
}
public record RouteResult(int DistanceMeters, int DurationSeconds, string Source, string? Geometry = null);
public record MapPlace(string PlaceId, double Latitude, double Longitude, string Address);
public interface IMapProvider
{
    Task<RouteResult> Route(GeoPoint pickup, GeoPoint dropoff, string service, CancellationToken ct);
    Task<IReadOnlyList<MapPlace>> Search(string query, CancellationToken ct) =>
        throw new RuleException("DEPENDENCY_UNAVAILABLE", "Tìm địa điểm chưa sẵn sàng. Bạn có thể chọn ghim trên bản đồ.", 503);
}
public record NearbyService(string Code, int AvailableCount);
public record NearbyServices(bool InServiceZone, int RadiusMeters, DateTime ServerTime, IReadOnlyList<NearbyService> Items);
public interface IOtpProvider { Task Send(string phone, string code, CancellationToken ct); }
public interface ISecrets { string Hash(string value); string Hmac(string value); string Protect(string value); string Unprotect(string value); }
public record QuoteRequest(GeoPoint Pickup, GeoPoint Dropoff, string ServiceTypeCode, string PaymentMethodType = "CASH");
public record RideRequest(string QuoteId, string? PickupNote = null);
public record RideCommand(int ExpectedVersion, string? PickupPin = null, LocationEvidence? Location = null, string? ReasonCode = null, string? CompletionType = null);
public record LocationEvidence(double Latitude, double Longitude, double AccuracyMeters, DateTime RecordedAt, long Sequence = 0, string? SampleId = null);
public record CashRequest(string OperationId, long CollectedAmount, string Currency, string ReasonCode);
public record ReviewRequest(int ExpectedVersion, string Decision, string ReasonCode);
public record TicketRequest(string Subject, string Category, string Message, string? RideId = null, string Priority = "NORMAL");
