namespace GrapSolution.Domain;
public sealed class RideContactAttempt : Entity
{
    public string RideId { get; set; } = "";
    public string DriverId { get; set; } = "";
    public string Channel { get; set; } = "";
    public string Note { get; set; } = "";
}
