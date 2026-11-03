using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
namespace GrapSolution.Infrastructure;

public sealed class GrapDbContext(DbContextOptions<GrapDbContext> options) : DbContext(options), IGrapStore
{
    public IQueryable<T> Query<T>() where T : Entity => Set<T>();
    void IGrapStore.Add<T>(T entity) => Set<T>().Add(entity);
    public Task Save(CancellationToken ct = default) => SaveChangesAsync(ct);
    protected override void OnModelCreating(ModelBuilder b)
    {
        foreach (var type in typeof(Entity).Assembly.GetTypes().Where(t => t.IsSubclassOf(typeof(Entity)))) { b.Entity(type).HasKey(nameof(Entity.Id)); b.Entity(type).Property(nameof(Entity.Id)).HasMaxLength(64); }
        b.Entity<User>().HasIndex(u => u.Phone).IsUnique();
        b.Entity<PushDevice>().HasIndex(d => new { d.InstallationId, d.AppType }).IsUnique();
        b.Entity<PushDevice>().HasIndex(d => d.TokenHash).IsUnique().HasFilter("\"RevokedAt\" IS NULL");
        b.Entity<PushDevice>().HasOne<User>().WithMany().HasForeignKey(d => d.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<PushDevice>().HasOne<Session>().WithMany().HasForeignKey(d => d.SessionId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<PushDelivery>().HasIndex(d => new { d.NotificationId, d.DeviceId }).IsUnique();
        b.Entity<PushDelivery>().HasIndex(d => new { d.Status, d.NextAttemptAt });
        b.Entity<PushDelivery>().HasOne<Notification>().WithMany().HasForeignKey(d => d.NotificationId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<PushDelivery>().HasOne<PushDevice>().WithMany().HasForeignKey(d => d.DeviceId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Session>().HasIndex(s => s.RefreshHash).IsUnique(); b.Entity<Session>().HasOne<User>().WithMany().HasForeignKey(s => s.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Driver>().HasIndex(d => d.UserId).IsUnique(); b.Entity<Driver>().HasOne<User>().WithMany().HasForeignKey(d => d.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Ride>().HasIndex(r => r.QuoteId).IsUnique(); b.Entity<Ride>().HasIndex(r => r.CustomerId).IsUnique().HasFilter("\"Status\" IN ('SEARCHING','ASSIGNED','DRIVER_ARRIVED','IN_PROGRESS')");
        b.Entity<Ride>().HasIndex(r => new { r.Status, r.DeadlineAt }); b.Entity<Ride>().HasIndex(r => new { r.CustomerId, r.CreatedAt, r.Id });
        b.Entity<Ride>().HasOne<User>().WithMany().HasForeignKey(r => r.CustomerId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Ride>().HasOne<Quote>().WithMany().HasForeignKey(r => r.QuoteId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Ride>().HasOne<Driver>().WithMany().HasForeignKey(r => r.DriverId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Ride>().Property(r => r.Version).IsConcurrencyToken();
        b.Entity<Assignment>().HasIndex(a => a.RideId).IsUnique().HasFilter("\"EndedAt\" IS NULL"); b.Entity<Assignment>().HasIndex(a => a.DriverId).IsUnique().HasFilter("\"EndedAt\" IS NULL");
        b.Entity<Assignment>().HasOne<Ride>().WithMany().HasForeignKey(a => a.RideId).OnDelete(DeleteBehavior.Restrict); b.Entity<Assignment>().HasOne<Driver>().WithMany().HasForeignKey(a => a.DriverId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Offer>().HasIndex(o => o.RideId).IsUnique().HasFilter("\"Status\" = 'OPEN'"); b.Entity<Offer>().HasIndex(o => o.DriverId).IsUnique().HasFilter("\"Status\" = 'OPEN'");
        b.Entity<Offer>().HasOne<Ride>().WithMany().HasForeignKey(o => o.RideId).OnDelete(DeleteBehavior.Restrict); b.Entity<Offer>().HasOne<Driver>().WithMany().HasForeignKey(o => o.DriverId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<RideEvent>().HasIndex(e => new { e.RideId, e.Sequence }).IsUnique(); b.Entity<RideEvent>().HasOne<Ride>().WithMany().HasForeignKey(e => e.RideId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Payment>().HasIndex(p => p.RideId).IsUnique(); b.Entity<Payment>().HasOne<Ride>().WithMany().HasForeignKey(p => p.RideId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<CashCollection>().HasIndex(c => c.OperationId).IsUnique(); b.Entity<CashCollection>().HasOne<Payment>().WithMany().HasForeignKey(c => c.PaymentId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Journal>().HasIndex(j => j.OperationKey).IsUnique(); b.Entity<Journal>().HasMany(j => j.Entries).WithOne().HasForeignKey(e => e.JournalId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Rating>().HasIndex(r => new { r.RideId, r.AuthorId }).IsUnique(); b.Entity<ShareToken>().HasIndex(s => s.TokenHash).IsUnique();
        b.Entity<IdempotencyRecord>().HasIndex(i => new { i.ActorId, i.Scope, i.Key }).IsUnique();
        b.Entity<FarePolicy>().HasIndex(p => new { p.ZoneId, p.ServiceTypeCode, p.Version }).IsUnique();
        b.Entity<Driver>().Property(d => d.Version).IsConcurrencyToken(); b.Entity<SupportTicket>().Property(t => t.Version).IsConcurrencyToken();
        b.Entity<LocationSample>().HasIndex(s => new { s.DriverId, s.SessionId, s.SampleId }).IsUnique();
        b.Entity<RideContactAttempt>().HasOne<Ride>().WithMany().HasForeignKey(a => a.RideId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<RideContactAttempt>().HasIndex(a => new { a.RideId, a.DriverId, a.CreatedAt });
        b.Entity<DriverDocument>().HasOne<Driver>().WithMany().HasForeignKey(d => d.DriverId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<SavedPlace>().HasOne<User>().WithMany().HasForeignKey(p => p.CustomerId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<SavedPlace>().HasIndex(p => new { p.CustomerId, p.LabelKey }).IsUnique().HasFilter("\"DeletedAt\" IS NULL");
        b.Entity<SavedPlace>().Property(p => p.Version).IsConcurrencyToken();
        b.Entity<TrustedContact>().HasOne<User>().WithMany().HasForeignKey(c => c.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<TrustedContact>().HasIndex(c => new { c.UserId, c.DeletedAt });
        b.Entity<TrustedContact>().Property(c => c.Version).IsConcurrencyToken();
        b.Entity<AccountDeletionRequest>().HasOne<User>().WithMany().HasForeignKey(r => r.UserId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<AccountDeletionRequest>().HasIndex(r => r.UserId).IsUnique().HasFilter("\"Status\" IN ('REQUESTED','BLOCKED_OBLIGATIONS','IN_REVIEW','NEEDS_INFORMATION')");
        b.Entity<AccountDeletionRequest>().Property(r => r.Version).IsConcurrencyToken();
        b.Entity<PrivateFile>().HasOne<User>().WithMany().HasForeignKey(f => f.OwnerId).OnDelete(DeleteBehavior.Restrict);
        b.Entity<Payment>().ToTable(t => t.HasCheckConstraint("CK_Payment_Amounts", "\"PayableAmount\" >= 0 AND \"PaidAmount\" >= 0 AND \"PaidAmount\" <= \"PayableAmount\""));
        b.Entity<CashCollection>().ToTable(t => t.HasCheckConstraint("CK_Cash_Amount", "\"Amount\" >= 0"));
        b.Entity<LedgerEntry>().ToTable(t => t.HasCheckConstraint("CK_Ledger_Sides", "\"Debit\" >= 0 AND \"Credit\" >= 0 AND NOT (\"Debit\" > 0 AND \"Credit\" > 0)"));
        b.Entity<Rating>().ToTable(t => t.HasCheckConstraint("CK_Rating_Stars", "\"Stars\" >= 1 AND \"Stars\" <= 5"));
        foreach (var entity in new[] { typeof(Ride), typeof(Quote) })
        {
            foreach (var property in new[] { "Pickup", "Dropoff" }) { var p = b.Entity(entity).Property<GeoPoint>(property); p.HasConversion(v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null), v => JsonSerializer.Deserialize<GeoPoint>(v, (JsonSerializerOptions?)null)!); p.Metadata.SetValueComparer(new ValueComparer<GeoPoint>((x, y) => x == y, x => x.GetHashCode(), x => x)); }
            var fare = b.Entity(entity).Property<FareBreakdown>("Fare"); fare.HasConversion(v => JsonSerializer.Serialize(v, (JsonSerializerOptions?)null), v => JsonSerializer.Deserialize<FareBreakdown>(v, (JsonSerializerOptions?)null)!); fare.Metadata.SetValueComparer(new ValueComparer<FareBreakdown>((x, y) => x == y, x => x.GetHashCode(), x => x));
        }
    }
    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        if (ChangeTracker.Entries().Any(e => e.State is EntityState.Modified or EntityState.Deleted && e.Entity is Journal or LedgerEntry or AuditLog or RideEvent)) throw new InvalidOperationException("Posted ledger, events and audit records are immutable.");
        foreach (var j in ChangeTracker.Entries<Journal>().Where(e => e.State == EntityState.Added)) j.Entity.Validate();
        var now = DateTime.UtcNow;
        foreach (var notification in ChangeTracker.Entries<Notification>().Where(e => e.State == EntityState.Added).Select(e => e.Entity).ToList())
        {
            var devices = await Set<PushDevice>().Where(d => d.UserId == notification.UserId && d.RevokedAt == null && Set<Session>().Any(s => s.Id == d.SessionId && s.RevokedAt == null && s.ExpiresAt > now) && Set<User>().Any(u => u.Id == d.UserId && u.Status == "ACTIVE")).ToListAsync(cancellationToken);
            var offer = notification.Kind == "offer" ? await Set<Offer>().FindAsync([notification.EntityId], cancellationToken) : null;
            foreach (var device in devices)
            {
                if (notification.Kind == "offer" && (offer == null || !await Set<Driver>().AnyAsync(d => d.UserId == device.UserId && d.ActiveSessionId == device.SessionId, cancellationToken))) continue;
                Add(new PushDelivery { NotificationId = notification.Id, DeviceId = device.Id, UserId = device.UserId, SessionId = device.SessionId, TokenHash = device.TokenHash, ExpiresAt = offer?.ExpiresAt ?? now.AddHours(1) });
            }
        }
        return await base.SaveChangesAsync(cancellationToken);
    }
}
