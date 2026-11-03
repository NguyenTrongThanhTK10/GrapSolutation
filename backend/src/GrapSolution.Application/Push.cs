namespace GrapSolution.Application;

public record PushPayload(string Token, string Title, string Body, IReadOnlyDictionary<string, string> Data, TimeSpan Ttl);
public record PushSendResult(string Status, string? Error = null, TimeSpan? RetryAfter = null)
{
    public static PushSendResult Sent() => new("SENT");
    public static PushSendResult Retry(string code, TimeSpan? after = null) => new("RETRY", code, after);
}
public interface IPushSender
{
    bool Enabled { get; }
    Task<PushSendResult> Send(PushPayload payload, CancellationToken ct);
}
