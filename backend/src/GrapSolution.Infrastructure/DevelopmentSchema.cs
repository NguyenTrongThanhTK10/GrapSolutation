using Microsoft.EntityFrameworkCore;
namespace GrapSolution.Infrastructure;
public static class DevelopmentSchema
{
    public static async Task UpgradeSqlite(GrapDbContext db, CancellationToken ct = default)
    {
        await db.Database.OpenConnectionAsync(ct);
        try
        {
            var connection = db.Database.GetDbConnection();
            await using var command = connection.CreateCommand();
            command.CommandText = "PRAGMA table_info('DriverDocument')";
            var columns = new HashSet<string>();
            await using (var reader = await command.ExecuteReaderAsync(ct))
                while (await reader.ReadAsync(ct)) columns.Add(reader.GetString(1));
            if (!columns.Contains("ReviewReason"))
                await db.Database.ExecuteSqlRawAsync("ALTER TABLE \"DriverDocument\" ADD COLUMN \"ReviewReason\" TEXT NULL", ct);
            command.CommandText = "PRAGMA table_info('Notification')";
            columns.Clear();
            await using (var reader = await command.ExecuteReaderAsync(ct))
                while (await reader.ReadAsync(ct)) columns.Add(reader.GetString(1));
            if (!columns.Contains("Kind"))
                await db.Database.ExecuteSqlRawAsync("ALTER TABLE \"Notification\" ADD COLUMN \"Kind\" TEXT NOT NULL DEFAULT 'ride'", ct);
        }
        finally { await db.Database.CloseConnectionAsync(); }
    }
}
