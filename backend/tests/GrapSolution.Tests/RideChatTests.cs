using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using GrapSolution.Application;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class RideChatTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private record Conversation(string RideId, string AssignmentId, string CustomerId, string DriverUserId, string DriverId);

    private async Task<Conversation> Create()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
        var customer = new User { Phone = Guid.NewGuid().ToString(), Name = "Khách chat" };
        var driverUser = new User { Phone = Guid.NewGuid().ToString(), Name = "Tài xế chat", Role = Roles.Driver };
        var driver = new Driver { UserId = driverUser.Id };
        var quote = new Quote { CustomerId = customer.Id };
        var ride = new Ride { CustomerId = customer.Id, DriverId = driver.Id, QuoteId = quote.Id, Status = "ASSIGNED" };
        var assignment = new Assignment { RideId = ride.Id, DriverId = driver.Id };
        db.AddRange(customer, driverUser, driver, quote, ride, assignment);
        await db.SaveChangesAsync();
        return new(ride.Id, assignment.Id, customer.Id, driverUser.Id, driver.Id);
    }

    private async Task<HttpClient> Login(string id)
    {
        var client = factory.CreateClient();
        var login = await Ok(await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = id, deviceId = Guid.NewGuid().ToString() }));
        client.DefaultRequestHeaders.Authorization = new("Bearer", login.GetProperty("accessToken").GetString());
        return client;
    }

    private static async Task<JsonElement> Ok(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"{response.StatusCode}: {body}");
        return JsonDocument.Parse(body).RootElement.Clone();
    }

    private static string Path(Conversation chat) => $"/api/v1/rides/{chat.RideId}/messages";
    private static Task<HttpResponseMessage> Send(HttpClient client, Conversation chat, string? text, string? key = null, string? assignmentId = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, Path(chat))
        {
            Content = JsonContent.Create(new { assignmentId = assignmentId ?? chat.AssignmentId, body = text, senderId = "forged-user" })
        };
        request.Headers.Add("Idempotency-Key", key ?? Guid.NewGuid().ToString());
        return client.SendAsync(request);
    }

    [Fact]
    public async Task Participants_exchange_ordered_messages_with_server_identity_and_encrypted_storage()
    {
        var chat = await Create();
        var customer = await Login(chat.CustomerId); var driver = await Login(chat.DriverUserId);
        var sent = await Ok(await Send(customer, chat, "  Tôi đang ở cổng chính.  "));
        Assert.Equal(chat.CustomerId, sent.GetProperty("senderId").GetString());
        Assert.Equal("Tôi đang ở cổng chính.", sent.GetProperty("body").GetString());
        await Ok(await Send(driver, chat, "Tôi đã đến."));
        var page = await Ok(await customer.GetAsync(Path(chat)));
        Assert.True(page.GetProperty("canSend").GetBoolean());
        Assert.Equal("Tài xế chat", page.GetProperty("peerName").GetString());
        Assert.Equal(new[] { 1, 2 }, page.GetProperty("items").EnumerateArray().Select(m => m.GetProperty("sequence").GetInt32()));
        Assert.Equal(2, (await Ok(await driver.GetAsync(Path(chat)))).GetProperty("items").GetArrayLength());
        using var scope = factory.Services.CreateScope(); var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
        Assert.All(db.Set<RideChatMessage>().Where(m => m.RideId == chat.RideId), m => Assert.DoesNotContain("cổng chính", m.BodyProtected));
        Assert.All(db.Set<OutboxMessage>().Where(m => m.AggregateId == chat.RideId), m => Assert.DoesNotContain("cổng chính", m.Payload));
        var notifications = db.Set<Notification>().Where(n => n.EntityId == chat.RideId).ToList();
        Assert.Equal(2, notifications.Count);
        Assert.All(notifications, n => { Assert.Equal("chat", n.Kind); Assert.DoesNotContain("cổng chính", n.Body); });
    }

    [Fact]
    public async Task Unrelated_users_staff_and_anonymous_cannot_read_or_send()
    {
        var chat = await Create();
        foreach (var user in new[] { "customer-1", "driver-user-1", "staff-SupportAgent" })
        {
            var outsider = await Login(user);
            var expected = user.StartsWith("staff") ? HttpStatusCode.Forbidden : HttpStatusCode.NotFound;
            Assert.Equal(expected, (await outsider.GetAsync(Path(chat))).StatusCode);
            Assert.Equal(expected, (await Send(outsider, chat, "Không có quyền")).StatusCode);
        }
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync(Path(chat))).StatusCode);
        var customer = await Login(chat.CustomerId);
        Assert.Equal(HttpStatusCode.BadRequest, (await customer.PostAsJsonAsync(Path(chat), new { assignmentId = chat.AssignmentId, body = "Thiếu khóa" })).StatusCode);
    }

    [Fact]
    public async Task Retry_is_idempotent_and_completion_closes_writes_but_preserves_history()
    {
        var chat = await Create(); var customer = await Login(chat.CustomerId); var key = Guid.NewGuid().ToString();
        var original = await Ok(await Send(customer, chat, "Chờ tôi nhé", key));
        Assert.Equal(original.GetProperty("id").GetString(), (await Ok(await Send(customer, chat, "Chờ tôi nhé", key))).GetProperty("id").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await Send(customer, chat, "Nội dung khác", key)).StatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            db.Set<Ride>().Single(r => r.Id == chat.RideId).Change("COMPLETED");
            db.Set<Assignment>().Single(a => a.Id == chat.AssignmentId).EndedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        Assert.Equal(original.GetProperty("id").GetString(), (await Ok(await Send(customer, chat, "Chờ tôi nhé", key))).GetProperty("id").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await Send(customer, chat, "Gửi sau chuyến")).StatusCode);
        var history = await Ok(await customer.GetAsync(Path(chat)));
        Assert.False(history.GetProperty("canSend").GetBoolean());
        Assert.Single(history.GetProperty("items").EnumerateArray());
    }

    [Fact]
    public async Task Reassignment_revokes_old_driver_and_isolates_threads_including_retry_responses()
    {
        var chat = await Create(); var customer = await Login(chat.CustomerId); var oldDriver = await Login(chat.DriverUserId);
        var key = Guid.NewGuid().ToString(); await Ok(await Send(oldDriver, chat, "Tin của tài xế cũ", key));
        string nextAssignment;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            db.Set<Assignment>().Single(a => a.Id == chat.AssignmentId).EndedAt = DateTime.UtcNow;
            db.Set<Ride>().Single(r => r.Id == chat.RideId).DriverId = "driver-3";
            var next = new Assignment { RideId = chat.RideId, DriverId = "driver-3" };
            db.Add(next); await db.SaveChangesAsync(); nextAssignment = next.Id;
        }
        Assert.Equal(HttpStatusCode.NotFound, (await oldDriver.GetAsync(Path(chat))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await Send(oldDriver, chat, "Tin của tài xế cũ", key)).StatusCode);
        var nextDriver = await Login("driver-user-3");
        Assert.Empty((await Ok(await nextDriver.GetAsync(Path(chat)))).GetProperty("items").EnumerateArray());
        Assert.Empty((await Ok(await customer.GetAsync(Path(chat)))).GetProperty("items").EnumerateArray());
        Assert.Equal(HttpStatusCode.Conflict, (await Send(customer, chat, "Bản nháp cũ")).StatusCode);
        await Ok(await Send(customer, chat, "Xin chào tài xế mới", assignmentId: nextAssignment));
        Assert.Single((await Ok(await nextDriver.GetAsync(Path(chat)))).GetProperty("items").EnumerateArray());
        // Release-assignment also blocks access while the ride searches for a replacement.
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            var ride = db.Set<Ride>().Single(r => r.Id == chat.RideId); ride.DriverId = null; ride.Status = "SEARCHING";
            db.Set<Assignment>().Single(a => a.Id == nextAssignment).EndedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }
        Assert.Equal(HttpStatusCode.Conflict, (await customer.GetAsync(Path(chat))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await nextDriver.GetAsync(Path(chat))).StatusCode);
    }

    [Fact]
    public async Task Pagination_recovers_every_message_even_with_equal_timestamps()
    {
        var chat = await Create(); var customer = await Login(chat.CustomerId);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>(); var secrets = scope.ServiceProvider.GetRequiredService<ISecrets>();
            var timestamp = DateTime.UtcNow;
            for (var i = 1; i <= 123; i++) db.Add(new RideChatMessage { RideId = chat.RideId, AssignmentId = chat.AssignmentId, SenderId = chat.CustomerId, Sequence = i, CreatedAt = timestamp, BodyProtected = secrets.Protect($"Tin {i}") });
            await db.SaveChangesAsync();
        }
        var latest = await Ok(await customer.GetAsync(Path(chat)));
        Assert.Equal(74, latest.GetProperty("items")[0].GetProperty("sequence").GetInt32());
        Assert.Equal(74, latest.GetProperty("nextBeforeSequence").GetInt32());
        var older = await Ok(await customer.GetAsync(Path(chat) + "?beforeSequence=74"));
        Assert.Equal(24, older.GetProperty("items")[0].GetProperty("sequence").GetInt32());
        var recovered = new List<int>(); var after = 0; bool more;
        do
        {
            var page = await Ok(await customer.GetAsync(Path(chat) + "?afterSequence=" + after));
            recovered.AddRange(page.GetProperty("items").EnumerateArray().Select(m => m.GetProperty("sequence").GetInt32()));
            after = recovered.Last(); more = page.GetProperty("hasMore").GetBoolean();
        } while (more);
        Assert.Equal(Enumerable.Range(1, 123), recovered);
    }

    [Fact]
    public async Task Concurrent_sends_have_unique_sequence_and_repeated_key_creates_one_message()
    {
        var chat = await Create(); var customer = await Login(chat.CustomerId);
        var key = Guid.NewGuid().ToString();
        var responses = await Task.WhenAll(Enumerable.Range(0, 8).Select(_ => Send(customer, chat, "Gửi lại", key)));
        var ids = new List<string?>();
        foreach (var response in responses) ids.Add((await Ok(response)).GetProperty("id").GetString());
        Assert.Single(ids.Distinct());
        var messages = await Task.WhenAll(Enumerable.Range(0, 8).Select(i => Send(customer, chat, $"Tin mới {i}")));
        foreach (var response in messages) await Ok(response);
        var page = await Ok(await customer.GetAsync(Path(chat)));
        Assert.Equal(Enumerable.Range(1, 9), page.GetProperty("items").EnumerateArray().Select(m => m.GetProperty("sequence").GetInt32()));
    }

    [Fact]
    public async Task Send_rate_limit_is_per_authenticated_user_and_does_not_block_reads()
    {
        var first = await Create(); var second = await Create();
        var a = await Login(first.CustomerId); var b = await Login(second.CustomerId);
        for (var i = 0; i < 30; i++)
            Assert.Equal(HttpStatusCode.BadRequest, (await Send(a, first, "  ")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Send(a, first, "Vượt giới hạn")).StatusCode);
        await Ok(await a.GetAsync(Path(first)));
        await Ok(await Send(b, second, "Tài khoản khác vẫn gửi được"));
    }

    [Fact]
    public async Task Empty_oversized_and_invalid_pagination_requests_are_rejected()
    {
        var chat = await Create(); var customer = await Login(chat.CustomerId);
        foreach (var text in new[] { null, "  \n ", new string('a', 1001), "bad\u0000control" })
            Assert.Equal(HttpStatusCode.BadRequest, (await Send(customer, chat, text)).StatusCode);
        foreach (var query in new[] { "?beforeSequence=0", "?afterSequence=-1", "?beforeSequence=3&afterSequence=1" })
            Assert.Equal(HttpStatusCode.BadRequest, (await customer.GetAsync(Path(chat) + query)).StatusCode);
    }
}
