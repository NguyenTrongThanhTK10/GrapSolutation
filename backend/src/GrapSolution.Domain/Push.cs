namespace GrapSolution.Domain;

public sealed class PushDevice : Entity
{
    public string InstallationId { get; set; } = "";
    public string AppType { get; set; } = "";
    public string Platform { get; set; } = "android";
    public string UserId { get; set; } = "";
    public string SessionId { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public string TokenProtected { get; set; } = "";
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAt { get; set; }
}

public sealed class PushDelivery : Entity
{
    public string NotificationId { get; set; } = "";
    public string DeviceId { get; set; } = "";
    public string UserId { get; set; } = "";
    public string SessionId { get; set; } = "";
    public string TokenHash { get; set; } = "";
    public string Status { get; set; } = "PENDING";
    public int Attempts { get; set; }
    public DateTime NextAttemptAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddHours(1);
    public DateTime? SentAt { get; set; }
    public string? LastError { get; set; }
}
