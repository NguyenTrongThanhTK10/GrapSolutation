using System.Text.Json;
using System.Text;
using System.Globalization;
using GrapSolution.Application;
using GrapSolution.Domain;
namespace GrapSolution.Infrastructure;

public sealed class DemoMapProvider : IMapProvider
{
    public static readonly (string Id, GeoPoint Point)[] Places = [("ben-thanh", new(10.7721, 106.6983, "Chợ Bến Thành, Quận 1")), ("landmark", new(10.7951, 106.7218, "Landmark 81, Bình Thạnh")), ("airport", new(10.8131, 106.6520, "Sân bay Tân Sơn Nhất, Tân Bình")), ("bitexco", new(10.7717, 106.7045, "Bitexco Financial Tower, Quận 1")), ("nhatho", new(10.7798, 106.6990, "Nhà thờ Đức Bà, Quận 1"))];
    private static readonly int[,] Distances = { { 0, 6300, 8500, 1200, 1800 }, { 6300, 0, 11200, 5900, 4900 }, { 8500, 11200, 0, 9700, 7800 }, { 1200, 5900, 9700, 0, 2200 }, { 1800, 4900, 7800, 2200, 0 } };
    public static string SearchKey(string value) => string.Concat(value.Normalize(NormalizationForm.FormD)
        .Where(c => CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark))
        .Replace('đ', 'd').Replace('Đ', 'D').ToLowerInvariant();
    public Task<IReadOnlyList<MapPlace>> Search(string query, CancellationToken ct)
    {
        var words = SearchKey(query).Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return Task.FromResult<IReadOnlyList<MapPlace>>(Places.Where(p => words.All(word =>
            SearchKey(p.Point.Address + (p.Id == "airport" ? " TSN SGN" : "")).Contains(word)))
            .Select(p => new MapPlace(p.Id, p.Point.Latitude, p.Point.Longitude, p.Point.Address)).ToList());
    }
    public Task<RouteResult> Route(GeoPoint pickup, GeoPoint dropoff, string service, CancellationToken ct)
    {
        var a = Array.FindIndex(Places, p => p.Point.DistanceTo(pickup) < 150); var b = Array.FindIndex(Places, p => p.Point.DistanceTo(dropoff) < 150);
        if (a < 0 || b < 0 || a == b) throw new RuleException("ROUTE_UNAVAILABLE", "Chế độ demo chỉ hỗ trợ các địa điểm mẫu được cung cấp.", 422);
        var distance = Distances[a, b]; return Task.FromResult(new RouteResult(distance, (int)Math.Ceiling(distance / (service == "BIKE" ? 6m : 5m)), "DEVELOPMENT_FIXTURE"));
    }
}
public sealed class HttpMapProvider(HttpClient client, string baseUrl) : IMapProvider
{
    public async Task<IReadOnlyList<MapPlace>> Search(string query, CancellationToken ct)
    {
        try
        {
            using var response = await client.GetAsync(baseUrl.TrimEnd('/') + "/autocomplete?q=" + Uri.EscapeDataString(query), ct);
            response.EnsureSuccessStatusCode();
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            return json.RootElement.GetProperty("items").EnumerateArray().Take(20).Select(item =>
            {
                var place = new MapPlace(item.GetProperty("placeId").GetString() ?? "", item.GetProperty("latitude").GetDouble(),
                    item.GetProperty("longitude").GetDouble(), item.GetProperty("address").GetString() ?? "");
                if (string.IsNullOrWhiteSpace(place.PlaceId) || place.PlaceId.Length > 200 || string.IsNullOrWhiteSpace(place.Address) || place.Address.Length > 500 ||
                    !double.IsFinite(place.Latitude) || !double.IsFinite(place.Longitude) || place.Latitude is < -90 or > 90 || place.Longitude is < -180 or > 180)
                    throw new JsonException("Invalid provider place.");
                return place;
            }).ToList();
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException or InvalidOperationException or KeyNotFoundException or FormatException)
        { throw new RuleException("DEPENDENCY_UNAVAILABLE", "Chưa tìm được địa điểm từ nhà cung cấp. Bạn có thể thử lại hoặc chọn trên bản đồ.", 503); }
    }
    public async Task<RouteResult> Route(GeoPoint pickup, GeoPoint dropoff, string service, CancellationToken ct)
    {
        try { using var response = await client.PostAsync(baseUrl.TrimEnd('/') + "/route", new StringContent(JsonSerializer.Serialize(new { pickup, dropoff, serviceTypeCode = service }), System.Text.Encoding.UTF8, "application/json"), ct); response.EnsureSuccessStatusCode(); using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct)); var r = json.RootElement; return new(r.GetProperty("distanceMeters").GetInt32(), r.GetProperty("durationSeconds").GetInt32(), "CONFIGURED_PROVIDER", r.TryGetProperty("geometry", out var geometry) ? geometry.GetRawText() : null); }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException) { throw new RuleException("DEPENDENCY_UNAVAILABLE", "Nhà cung cấp bản đồ chưa sẵn sàng. Vui lòng thử lại.", 503); }
    }
}
public sealed class UnconfiguredOtpProvider : IOtpProvider { public Task Send(string phone, string code, CancellationToken ct) => throw new RuleException("DEPENDENCY_UNAVAILABLE", "Chưa cấu hình nhà cung cấp SMS. Môi trường local có đăng nhập phát triển riêng.", 503); }
