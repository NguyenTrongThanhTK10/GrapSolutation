using System.Data;
using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Infrastructure;

public sealed class AtomicExecutor(GrapDbContext db, ISecrets secrets)
{
    private static readonly SemaphoreSlim LocalGate = new(1, 1);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public async Task<(string Json, int Status)> Run(string actor, string scope, string? key, string payloadHash, Func<Task<object?>> action, int status = 200, CancellationToken ct = default)
    {
        if (key != null && (key.Length < 8 || key.Length > 150)) throw new RuleException("VALIDATION_ERROR", "Idempotency-Key phải có 8–150 ký tự.", 400);
        await LocalGate.WaitAsync(ct);
        try
        {
            await using var tx = await db.Database.BeginTransactionAsync(db.Database.IsNpgsql() ? IsolationLevel.ReadCommitted : IsolationLevel.Serializable, ct);
            // A transaction-scoped PostgreSQL lock protects cross-process command ordering.
            // Filtered unique indexes remain the final safeguard. Split this lock by aggregate when scaling.
            if (db.Database.IsNpgsql()) await db.Database.ExecuteSqlRawAsync("SELECT pg_advisory_xact_lock(721601)", ct);
            if (key != null)
            {
                var previous = await db.Set<IdempotencyRecord>().SingleOrDefaultAsync(i => i.ActorId == actor && i.Scope == scope && i.Key == key, ct);
                if (previous != null) { if (previous.PayloadHash != payloadHash) throw new RuleException("IDEMPOTENCY_CONFLICT", "Khóa đã được dùng với nội dung khác."); return (previous.ResponseJson.StartsWith("dp:", StringComparison.Ordinal) ? secrets.Unprotect(previous.ResponseJson[3..]) : previous.ResponseJson, previous.StatusCode); }
            }
            try
            {
                var response = await action(); await db.SaveChangesAsync(ct);
                var json = JsonSerializer.Serialize(response, Json);
                // Replay responses can contain pickup PINs, contact numbers and private addresses.
                // Protect them as well as the primary entities; keep read compatibility for older local records.
                if (key != null) { db.Add(new IdempotencyRecord { ActorId = actor, Scope = scope, Key = key, PayloadHash = payloadHash, ResponseJson = "dp:" + secrets.Protect(json), StatusCode = status }); await db.SaveChangesAsync(ct); }
                await tx.CommitAsync(ct); return (json, status);
            }
            catch (RuleException ex) when (ex.Persist) { await db.SaveChangesAsync(ct); await tx.CommitAsync(ct); throw; }
        }
        finally { LocalGate.Release(); }
    }
}
