using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.IdentityModel.Tokens;
namespace GrapSolution.Api;

public sealed class Secrets(IDataProtectionProvider protector, IConfiguration config) : ISecrets
{
    private readonly IDataProtector pinProtector = protector.CreateProtector("Grap.RidePin.v1");
    public string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    public string Hmac(string value) => Convert.ToHexString(HMACSHA256.HashData(Encoding.UTF8.GetBytes(config["Auth:SigningKey"]!), Encoding.UTF8.GetBytes(value)));
    public string Protect(string value) => pinProtector.Protect(value);
    public string Unprotect(string value) => pinProtector.Unprotect(value);
}
public static class Identity
{
    public static Actor Actor(this HttpContext ctx) => new(ctx.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? throw new RuleException("UNAUTHENTICATED", "Vui lòng đăng nhập.", 401), ctx.User.FindFirstValue(ClaimTypes.Role)!, ctx.User.FindFirstValue("zone")!, ctx.User.FindFirstValue("sid")!);
    public static object Issue(User user, Session session, string refreshToken, IConfiguration config)
    {
        var expires = DateTime.UtcNow.AddMinutes(15);
        var token = new JwtSecurityToken(issuer: "grap", audience: "grap-clients", claims: [new(ClaimTypes.NameIdentifier, user.Id), new(ClaimTypes.Role, user.Role), new("zone", user.ZoneId), new("sid", session.Id)], expires: expires, signingCredentials: new(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Auth:SigningKey"]!)), SecurityAlgorithms.HmacSha256));
        return new { accessToken = new JwtSecurityTokenHandler().WriteToken(token), refreshToken, expiresAt = expires, user = new { user.Id, user.Name, user.Role, user.ZoneId, phone = RideService.Mask(user.Phone) }, serverTime = DateTime.UtcNow };
    }
    public static (Session Session, string Token) NewSession(User user, string device, ISecrets secrets, string? family = null)
    { var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(48)); return (new Session { UserId = user.Id, DeviceId = device, RefreshHash = secrets.Hash(token), Family = family ?? Guid.NewGuid().ToString() }, token); }
}
public record DevelopmentLogin(string UserId, string DeviceId = "web-local");
public record OtpChallengeRequest(string Phone, string AppType);
public record OtpVerifyRequest(string ChallengeId, string Otp, string DeviceId);
public record RefreshRequest(string RefreshToken);
