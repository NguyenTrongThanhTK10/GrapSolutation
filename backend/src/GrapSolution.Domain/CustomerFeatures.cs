namespace GrapSolution.Domain;
public sealed class SavedPlace : Entity
{
    public string CustomerId { get; set; } = "";
    public string Label { get; set; } = "";
    public string LabelKey { get; set; } = "";
    public string Address { get; set; } = "";
    public string Note { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public int Version { get; set; } = 1;
    public DateTime? DeletedAt { get; set; }
}
public sealed class TrustedContact : Entity
{
    public string UserId { get; set; } = "";
    public string Name { get; set; } = "";
    public string PhoneProtected { get; set; } = "";
    public DateTime ConsentedAt { get; set; }
    public int Version { get; set; } = 1;
    public DateTime? DeletedAt { get; set; }
}
public sealed class AccountDeletionRequest : Entity
{
    public string UserId { get; set; } = "";
    public string ZoneId { get; set; } = "hcm";
    public string Status { get; set; } = "REQUESTED";
    public string Reason { get; set; } = "";
    public string? ReviewNote { get; set; }
    public string? ReviewerId { get; set; }
    public string TicketId { get; set; } = "";
    public int Version { get; set; } = 1;
    public DateTime? WithdrawnAt { get; set; }
    public static readonly string[] OpenStates = ["REQUESTED", "BLOCKED_OBLIGATIONS", "IN_REVIEW", "NEEDS_INFORMATION"];
}
