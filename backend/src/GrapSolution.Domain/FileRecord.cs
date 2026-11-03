namespace GrapSolution.Domain;
public sealed class PrivateFile : Entity
{
    public string OwnerId { get; set; } = "";
    public string Purpose { get; set; } = "DRIVER_DOCUMENT";
    public string ContentType { get; set; } = "";
    public long Size { get; set; }
    public string Status { get; set; } = "PENDING";
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddMinutes(10);
}
public sealed class LocationSample : Entity
{
    public string DriverId { get; set; } = "";
    public string SessionId { get; set; } = "";
    public string SampleId { get; set; } = "";
    public long Sequence { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double AccuracyMeters { get; set; }
    public DateTime RecordedAt { get; set; }
}
