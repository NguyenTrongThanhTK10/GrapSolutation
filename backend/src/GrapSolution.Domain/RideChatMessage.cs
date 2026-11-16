namespace GrapSolution.Domain;

public sealed class RideChatMessage : Entity
{
    public string RideId { get; set; } = "";
    public string AssignmentId { get; set; } = "";
    public string SenderId { get; set; } = "";
    public string BodyProtected { get; set; } = "";
    public int Sequence { get; set; }
}
