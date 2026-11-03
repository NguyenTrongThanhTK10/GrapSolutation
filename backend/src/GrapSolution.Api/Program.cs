using System.Text;
using System.Threading.RateLimiting;
using GrapSolution.Api;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
var development = builder.Environment.IsDevelopment();
if (string.IsNullOrWhiteSpace(builder.Configuration["Auth:SigningKey"]))
{
    if (!development) throw new InvalidOperationException("Auth__SigningKey must be configured outside Development.");
    Directory.CreateDirectory(".local"); var path = ".local/signing-key";
    if (!File.Exists(path)) File.WriteAllText(path, Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(48)));
    builder.Configuration["Auth:SigningKey"] = File.ReadAllText(path);
}
if (builder.Configuration["Auth:SigningKey"]!.Length < 48) throw new InvalidOperationException("Signing key must be at least 48 characters.");
builder.Services.AddDataProtection().SetApplicationName("GrapSolution").PersistKeysToFileSystem(new DirectoryInfo(builder.Configuration["DataProtection:KeyPath"] ?? ".local/keys"));
builder.Services.AddSingleton<ISecrets, Secrets>();
builder.Services.AddDbContext<GrapDbContext>(options => { var postgres = builder.Configuration.GetConnectionString("Postgres"); if (!string.IsNullOrWhiteSpace(postgres)) options.UseNpgsql(postgres); else if (development || builder.Environment.IsEnvironment("Testing")) options.UseSqlite(builder.Configuration.GetConnectionString("Sqlite") ?? "Data Source=grap.db;Foreign Keys=True;Default Timeout=30"); else throw new InvalidOperationException("PostgreSQL connection is required outside Development."); });
builder.Services.AddScoped<IGrapStore>(sp => sp.GetRequiredService<GrapDbContext>()); builder.Services.AddScoped<RideService>(); builder.Services.AddScoped<AtomicExecutor>();
builder.Services.AddSingleton<IOtpProvider, UnconfiguredOtpProvider>();
builder.Services.AddSingleton<IMapProvider>(_ => development && builder.Configuration["Maps:BaseUrl"] == null ? new DemoMapProvider() : new HttpMapProvider(new HttpClient { Timeout = TimeSpan.FromSeconds(10) }, builder.Configuration["Maps:BaseUrl"] ?? throw new InvalidOperationException("Maps__BaseUrl is required outside Development.")));
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.TokenValidationParameters = new() { ValidateIssuer = true, ValidIssuer = "grap", ValidateAudience = true, ValidAudience = "grap-clients", ValidateLifetime = true, ValidateIssuerSigningKey = true, IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Auth:SigningKey"]!)), ClockSkew = TimeSpan.FromSeconds(15) };
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context => { if (context.HttpContext.Request.Path.StartsWithSegments("/hubs")) context.Token = context.Request.Query["access_token"]; return Task.CompletedTask; },
        OnTokenValidated = async context => { var db = context.HttpContext.RequestServices.GetRequiredService<GrapDbContext>(); var sessionId = context.Principal!.FindFirst("sid")?.Value; var session = await db.Set<Session>().SingleOrDefaultAsync(s => s.Id == sessionId); if (session == null || session.RevokedAt != null || session.ExpiresAt <= DateTime.UtcNow || !await db.Set<User>().AnyAsync(u => u.Id == session.UserId && u.Status == "ACTIVE")) context.Fail("SESSION_EXPIRED"); }
    };
});
builder.Services.AddAuthorization(); builder.Services.AddSignalR(); builder.Services.AddOpenApi();
builder.Services.AddCors(options => options.AddDefaultPolicy(policy => policy.WithOrigins((builder.Configuration["AllowedOrigins"] ?? "http://127.0.0.1:5173,http://localhost:5173").Split(',')).AllowAnyHeader().AllowAnyMethod().AllowCredentials()));
builder.Services.AddRateLimiter(options => { options.RejectionStatusCode = 429; options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new() { PermitLimit = 300, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); options.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown", _ => new() { PermitLimit = 15, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 })); });
builder.Services.AddSingleton<IPushSender>(_ => new FirebasePushSender(builder.Configuration.GetValue<bool>("Firebase:Enabled"), builder.Configuration["Firebase:ProjectId"] ?? ""));
builder.Services.AddScoped<PushDispatcher>();
builder.Services.AddHostedService<OperationsWorker>();
builder.Services.AddHostedService<PushWorker>();
var app = builder.Build();
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff"; context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin"; context.Response.Headers.CacheControl = "no-store";
    try { await next(); }
    catch (Exception error)
    {
        if (context.Response.HasStarted) throw;
        var rule = error as RuleException; var code = rule?.Code ?? (error is DbUpdateConcurrencyException ? "VERSION_CONFLICT" : error is DbUpdateException ? "CONSTRAINT_CONFLICT" : error is BadHttpRequestException ? "VALIDATION_ERROR" : "INTERNAL_ERROR"); var status = rule?.Status ?? (error is DbUpdateException || error is DbUpdateConcurrencyException ? 409 : error is BadHttpRequestException ? 400 : 500);
        if (status == 500) app.Logger.LogError(error, "Unhandled error {TraceId}", context.TraceIdentifier);
        context.Response.StatusCode = status; await context.Response.WriteAsJsonAsync(new { type = "urn:grap:problem:" + code.ToLowerInvariant().Replace('_', '-'), title = rule?.Message ?? "Không thể xử lý yêu cầu.", status, code, traceId = context.TraceIdentifier, currentVersion = rule?.CurrentVersion });
    }
});
app.UseCors(); app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization();
app.MapGet("/health/live", () => Results.Ok(new { status = "ok" }));
app.MapGet("/health/ready", async (GrapDbContext db) => await db.Database.CanConnectAsync() ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503));
if (development) app.MapOpenApi();
app.MapGrapEndpoints(); app.MapHub<RideHub>("/hubs/rides", options => options.CloseOnAuthenticationExpiration = true);
await using (var scope = app.Services.CreateAsyncScope())
{
    var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
    if (db.Database.IsNpgsql()) await db.Database.MigrateAsync();
    else
    {
        await db.Database.EnsureCreatedAsync();
        // Add newly introduced development tables without discarding existing local rides.
        // PostgreSQL deployment uses the versioned migrations above.
        var script = db.Database.GenerateCreateScript().Replace("CREATE TABLE ", "CREATE TABLE IF NOT EXISTS ").Replace("CREATE UNIQUE INDEX ", "CREATE UNIQUE INDEX IF NOT EXISTS ").Replace("CREATE INDEX ", "CREATE INDEX IF NOT EXISTS ");
        await db.Database.ExecuteSqlRawAsync(script);
        await DevelopmentSchema.UpgradeSqlite(db);
    }
    if (development && builder.Configuration["Seed:Enabled"] != "false") await Seed.Development(db, scope.ServiceProvider.GetRequiredService<ISecrets>());
}
await app.RunAsync();
public partial class Program { }
