using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
namespace GrapSolution.Infrastructure;
// Migrations target PostgreSQL. SQLite is a separate local-development adapter using EnsureCreated.
public sealed class GrapDbContextFactory : IDesignTimeDbContextFactory<GrapDbContext>
{
    public GrapDbContext CreateDbContext(string[] args) => new(new DbContextOptionsBuilder<GrapDbContext>().UseNpgsql("Host=127.0.0.1;Database=grap;Username=grap;Password=design-time-only").Options);
}
