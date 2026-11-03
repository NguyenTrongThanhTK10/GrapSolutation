using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
namespace GrapSolution.Tests;

public sealed class JourneyFeatureTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string user)
    {
        var client = factory.CreateClient(); var j = await Ok(await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = user, deviceId = Guid.NewGuid().ToString() }));
        client.DefaultRequestHeaders.Authorization = new("Bearer", j.GetProperty("accessToken").GetString()); return client;
    }
    private static async Task<JsonElement> Ok(HttpResponseMessage r) { var text = await r.Content.ReadAsStringAsync(); Assert.True(r.IsSuccessStatusCode, $"{r.StatusCode}: {text}"); return JsonDocument.Parse(text).RootElement.Clone(); }
    private static Task<HttpResponseMessage> Post(HttpClient c, string path, object body, string? key = null)
    {
        var r = new HttpRequestMessage(HttpMethod.Post, "/api/v1" + path) { Content = JsonContent.Create(body) }; r.Headers.Add("Idempotency-Key", key ?? Guid.NewGuid().ToString()); return c.SendAsync(r);
    }
    private async Task<string> AddRide(string customer, DateTime at, string status = "COMPLETED", DateTime? ended = null)
    {
        using var scope = factory.Services.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
        var q = new Quote { CustomerId = customer }; var r = new Ride { CustomerId = customer, QuoteId = q.Id, CreatedAt = at, Status = status, EndedAt = ended ?? DateTime.UtcNow };
        db.Add(q); db.Add(r); await db.SaveChangesAsync(); return r.Id;
    }
    [Fact] public async Task History_cursor_handles_ties_and_new_inserts_and_rejects_tampering_or_changed_scope()
    {
        var c = await Login("customer-4"); var other = await Login("customer-3"); var at = DateTime.UtcNow.AddYears(3);
        var expected = new List<string>(); for(var i=0;i<3;i++) expected.Add(await AddRide("customer-4", at)); expected.Sort(StringComparer.Ordinal); expected.Reverse();
        var first = await Ok(await c.GetAsync("/api/v1/rides?status=COMPLETED&pageSize=2"));
        Assert.Equal(expected.Take(2), first.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("rideId").GetString()));
        var cursor = first.GetProperty("nextCursor").GetString()!; await AddRide("customer-4", at.AddDays(1));
        var next = await Ok(await c.GetAsync("/api/v1/rides?status=COMPLETED&pageSize=2&cursor=" + Uri.EscapeDataString(cursor)));
        Assert.Equal(expected[2], next.GetProperty("items")[0].GetProperty("rideId").GetString());
        foreach(var url in new[] { "/rides?status=CANCELED&cursor=" + Uri.EscapeDataString(cursor), "/rides?status=COMPLETED&cursor=" + Uri.EscapeDataString(cursor + "X"), "/rides?from=2027-01-02&to=2027-01-01" }) Assert.Equal(HttpStatusCode.BadRequest, (await c.GetAsync("/api/v1" + url)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await other.GetAsync("/api/v1/rides?status=COMPLETED&cursor=" + Uri.EscapeDataString(cursor))).StatusCode);
        var filtered = await Ok(await c.GetAsync("/api/v1/rides?from=" + Uri.EscapeDataString(at.ToString("O")) + "&to=" + Uri.EscapeDataString(at.AddHours(1).ToString("O")))); Assert.Equal(3, filtered.GetProperty("items").GetArrayLength());
    }
    [Fact] public async Task Saved_addresses_require_ownership_unique_labels_and_current_version_and_clear_deleted_pii()
    {
        var c = await Login("customer-0"); var other = await Login("customer-1"); var point = new { latitude = 10.77, longitude = 106.69, address = "Địa chỉ riêng" }; var key = Guid.NewGuid().ToString();
        var body = new { label = "Nhà", point, note = "Tầng hai" };
        var saved = await Ok(await Post(c,"/customers/me/saved-places",body,key)); var id = saved.GetProperty("id").GetString();
        Assert.Equal(id,(await Ok(await Post(c,"/customers/me/saved-places",body,key))).GetProperty("id").GetString());
        Assert.Equal(HttpStatusCode.Conflict,(await Post(c,"/customers/me/saved-places",new{label=" nhà ",point})).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound,(await other.PatchAsJsonAsync("/api/v1/customers/me/saved-places/"+id,new{label="Khác",point,expectedVersion=1})).StatusCode);
        await Ok(await c.PatchAsJsonAsync("/api/v1/customers/me/saved-places/"+id,new{label="Công ty",point,expectedVersion=1}));
        Assert.Equal(HttpStatusCode.Conflict,(await c.DeleteAsync("/api/v1/customers/me/saved-places/"+id+"?expectedVersion=1")).StatusCode);
        await Ok(await c.DeleteAsync("/api/v1/customers/me/saved-places/"+id+"?expectedVersion=2"));
        using var scope = factory.Services.CreateScope(); var row = scope.ServiceProvider.GetRequiredService<GrapDbContext>().Set<SavedPlace>().Single(x=>x.Id==id); Assert.Empty(row.Address); Assert.Empty(row.Note); Assert.Equal(0,row.Latitude);
    }
    [Fact] public async Task Trusted_contacts_require_consent_encrypt_phone_and_enforce_ownership_and_limit()
    {
        var c = await Login("driver-user-4"); var other = await Login("customer-2");
        Assert.Equal(HttpStatusCode.UnprocessableEntity,(await Post(c,"/me/trusted-contacts",new{name="Người thân",phone="0912345678",consentAccepted=false})).StatusCode);
        var saved = await Ok(await Post(c,"/me/trusted-contacts",new{name="Người thân",phone="0912345678",consentAccepted=true})); var id=saved.GetProperty("id").GetString(); Assert.Equal("+84912345678",saved.GetProperty("phone").GetString());
        using(var scope=factory.Services.CreateScope()) {
            var db=scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            Assert.DoesNotContain("912345678",db.Set<TrustedContact>().Single(x=>x.Id==id).PhoneProtected);
            var replay=db.Set<IdempotencyRecord>().Single(r=>r.ActorId=="driver-user-4" && r.Scope=="/api/v1/me/trusted-contacts");
            Assert.StartsWith("dp:",replay.ResponseJson);Assert.DoesNotContain("912345678",replay.ResponseJson);
        }
        Assert.Equal(HttpStatusCode.NotFound,(await other.DeleteAsync("/api/v1/me/trusted-contacts/"+id+"?expectedVersion=1")).StatusCode);
        for(var i=0;i<4;i++) await Ok(await Post(c,"/me/trusted-contacts",new{name="Liên hệ "+i,phone="0987654321",consentAccepted=true}));
        Assert.Equal(HttpStatusCode.UnprocessableEntity,(await Post(c,"/me/trusted-contacts",new{name="Vượt giới hạn",phone="0987654321",consentAccepted=true})).StatusCode);
        await Ok(await c.PatchAsJsonAsync("/api/v1/me/trusted-contacts/"+id,new{name="Tên mới",phone="0987654321",consentAccepted=true,expectedVersion=1}));
        Assert.Equal(HttpStatusCode.Conflict,(await c.DeleteAsync("/api/v1/me/trusted-contacts/"+id+"?expectedVersion=1")).StatusCode);
        await Ok(await c.DeleteAsync("/api/v1/me/trusted-contacts/"+id+"?expectedVersion=2"));
        using var check=factory.Services.CreateScope();Assert.Empty(check.ServiceProvider.GetRequiredService<GrapDbContext>().Set<TrustedContact>().Single(x=>x.Id==id).PhoneProtected);
    }
    [Fact] public async Task Account_deletion_checks_obligations_and_allows_review_or_withdrawal_without_claiming_erasure()
    {
        using(var scope=factory.Services.CreateScope()){var db=scope.ServiceProvider.GetRequiredService<GrapDbContext>();db.Add(new User{Id="privacy-user",Phone="+84888880111",Name="Privacy test"});await db.SaveChangesAsync();}
        var customer=await Login("privacy-user");var security=await Login("staff-SecurityAdmin");var operations=await Login("staff-OperationsAdmin");
        var ride=await AddRide("privacy-user",DateTime.UtcNow,"ASSIGNED");
        var request=await Ok(await Post(customer,"/me/account-deletion-requests",new{reason="Tôi không còn nhu cầu sử dụng"}));var id=request.GetProperty("id").GetString();
        Assert.Equal("BLOCKED_OBLIGATIONS",request.GetProperty("status").GetString());Assert.False(request.GetProperty("dataDeleted").GetBoolean());
        Assert.Equal(HttpStatusCode.Conflict,(await Post(customer,"/me/account-deletion-requests",new{reason="Yêu cầu thêm lần nữa"})).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,(await operations.GetAsync("/api/v1/admin/account-deletion-requests")).StatusCode);
        Assert.Equal(HttpStatusCode.UnprocessableEntity,(await Post(security,"/admin/account-deletion-requests/"+id+"/review",new{expectedVersion=1,decision="IN_REVIEW",reason="Đã kiểm tra yêu cầu"})).StatusCode);
        using(var scope=factory.Services.CreateScope()){var db=scope.ServiceProvider.GetRequiredService<GrapDbContext>();db.Set<Ride>().Single(r=>r.Id==ride).Change("CANCELED");await db.SaveChangesAsync();}
        var checkedRequest=await Ok(await Post(customer,"/me/account-deletion-requests/"+id+"/recheck",new{expectedVersion=1}));Assert.Equal("REQUESTED",checkedRequest.GetProperty("status").GetString());
        await Ok(await Post(security,"/admin/account-deletion-requests/"+id+"/review",new{expectedVersion=2,decision="IN_REVIEW",reason="Đã tiếp nhận kiểm tra dữ liệu"}));
        Assert.Equal(HttpStatusCode.BadRequest,(await Post(security,"/admin/account-deletion-requests/"+id+"/review",new{expectedVersion=3,decision="COMPLETED",reason="Không được xác nhận xóa giả"})).StatusCode);
        var withdrawn=await Ok(await Post(customer,"/me/account-deletion-requests/"+id+"/cancel",new{expectedVersion=3}));Assert.Equal("WITHDRAWN",withdrawn.GetProperty("status").GetString());
        using var verify=factory.Services.CreateScope();Assert.Equal("ACTIVE",verify.ServiceProvider.GetRequiredService<GrapDbContext>().Set<User>().Single(u=>u.Id=="privacy-user").Status);
    }
    [Fact] public async Task Ratings_are_editable_only_during_24_hours_after_completion()
    {
        var c=await Login("customer-1");var id=await AddRide("customer-1",DateTime.UtcNow);
        Assert.True((await Ok(await c.GetAsync("/api/v1/rides/"+id+"/ratings/me"))).GetProperty("canEdit").GetBoolean());
        await Ok(await c.PostAsJsonAsync("/api/v1/rides/"+id+"/ratings",new{stars=5,comment="Tốt"}));await Ok(await c.PostAsJsonAsync("/api/v1/rides/"+id+"/ratings",new{stars=4,comment="Cập nhật nhận xét"}));
        using(var scope=factory.Services.CreateScope()){var db=scope.ServiceProvider.GetRequiredService<GrapDbContext>();db.Set<Ride>().Single(r=>r.Id==id).EndedAt=DateTime.UtcNow.AddHours(-25);await db.SaveChangesAsync();}
        var own=await Ok(await c.GetAsync("/api/v1/rides/"+id+"/ratings/me"));Assert.False(own.GetProperty("canEdit").GetBoolean());Assert.Equal(4,own.GetProperty("rating").GetProperty("stars").GetInt32());
        Assert.Equal(HttpStatusCode.Conflict,(await c.PostAsJsonAsync("/api/v1/rides/"+id+"/ratings",new{stars=1,comment="Quá thời hạn"})).StatusCode);
    }
}
