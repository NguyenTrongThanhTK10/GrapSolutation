using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading.Channels;
using GrapSolution.Domain;
using GrapSolution.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace GrapSolution.Tests;

public sealed class RideChatRealtimeTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private async Task<HttpClient> Login(string user)
    {
        var client = factory.CreateClient();
        var result = await client.PostAsJsonAsync("/api/v1/auth/development", new { userId = user });
        result.EnsureSuccessStatusCode();
        var login = await result.Content.ReadFromJsonAsync<JsonElement>();
        client.DefaultRequestHeaders.Authorization = new("Bearer", login.GetProperty("accessToken").GetString());
        return client;
    }

    private static async Task<JsonElement> Receive(WebSocket socket, CancellationToken ct)
    {
        var buffer = new byte[8192]; var text = new StringBuilder();
        do
        {
            var part = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), ct);
            if (part.MessageType == WebSocketMessageType.Close) throw new OperationCanceledException();
            text.Append(Encoding.UTF8.GetString(buffer, 0, part.Count));
        } while (!text.ToString().Contains('\u001e'));
        return JsonDocument.Parse(text.ToString().Split('\u001e')[0]).RootElement.Clone();
    }

    private async Task<WebSocket> Connect(HttpClient client, CancellationToken ct)
    {
        var websocket = factory.Server.CreateWebSocketClient();
        websocket.ConfigureRequest = request => request.Headers.Authorization = client.DefaultRequestHeaders.Authorization!.ToString();
        var socket = await websocket.ConnectAsync(new Uri("ws://localhost/hubs/rides"), ct);
        await socket.SendAsync(Encoding.UTF8.GetBytes("{\"protocol\":\"json\",\"version\":1}\u001e"), WebSocketMessageType.Text, true, ct);
        await Receive(socket, ct);
        return socket;
    }

    private static async Task Pump(WebSocket socket, Channel<JsonElement> messages, CancellationToken ct)
    {
        // A continuous reader permits negative recipient assertions without canceling the socket itself.
        var buffer = new byte[8192]; var pending = "";
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var received = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), ct);
                if (received.MessageType == WebSocketMessageType.Close) return;
                pending += Encoding.UTF8.GetString(buffer, 0, received.Count);
                while (pending.IndexOf('\u001e') is var end && end >= 0)
                {
                    using var document = JsonDocument.Parse(pending[..end]); pending = pending[(end + 1)..];
                    var json = document.RootElement;
                    if (json.TryGetProperty("target", out var target) && target.GetString() == "ride.message.created")
                        await messages.Writer.WriteAsync(json.Clone(), ct);
                }
            }
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { }
    }

    private static async Task NoMessage(Channel<JsonElement> messages)
    {
        using var timeout = new CancellationTokenSource(TimeSpan.FromMilliseconds(700));
        await Assert.ThrowsAnyAsync<OperationCanceledException>(async () => await messages.Reader.ReadAsync(timeout.Token));
    }

    [Fact]
    public async Task Chat_invalidation_reaches_current_driver_excludes_staff_and_drops_queued_old_assignment_events()
    {
        var customer = await Login("customer-0"); var oldDriver = await Login("driver-user-0");
        var newDriver = await Login("driver-user-3"); var staff = await Login("staff-SupportAgent");
        string rideId, assignmentId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
            var quote = new Quote { CustomerId = "customer-0" };
            var ride = new Ride { CustomerId = "customer-0", DriverId = "driver-0", QuoteId = quote.Id, Status = "ASSIGNED" };
            var assignment = new Assignment { RideId = ride.Id, DriverId = "driver-0" };
            db.AddRange(quote, ride, assignment); await db.SaveChangesAsync();
            rideId = ride.Id; assignmentId = assignment.Id;
        }
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(25));
        using var oldSocket = await Connect(oldDriver, timeout.Token);
        using var newSocket = await Connect(newDriver, timeout.Token);
        using var staffSocket = await Connect(staff, timeout.Token);
        var oldMessages = Channel.CreateUnbounded<JsonElement>(); var newMessages = Channel.CreateUnbounded<JsonElement>();
        var staffMessages = Channel.CreateUnbounded<JsonElement>();
        var pumps = new[] { Pump(oldSocket, oldMessages, timeout.Token), Pump(newSocket, newMessages, timeout.Token), Pump(staffSocket, staffMessages, timeout.Token) };
        async Task<JsonElement> Send(string assignment)
        {
            var request = new HttpRequestMessage(HttpMethod.Post, $"/api/v1/rides/{rideId}/messages")
            { Content = JsonContent.Create(new { assignmentId = assignment, body = "Nội dung riêng tư" }) };
            request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
            var response = await customer.SendAsync(request); response.EnsureSuccessStatusCode();
            return await response.Content.ReadFromJsonAsync<JsonElement>();
        }
        try
        {
            var first = await Send(assignmentId);
            var update = await oldMessages.Reader.ReadAsync(timeout.Token);
            Assert.Contains(first.GetProperty("id").GetString()!, update.GetRawText());
            Assert.DoesNotContain("Nội dung riêng tư", update.GetRawText());
            Assert.DoesNotContain("body", update.GetRawText());
            await Task.WhenAll(NoMessage(newMessages), NoMessage(staffMessages));
            string nextAssignment;
            using (var scope = factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<GrapDbContext>();
                db.Set<Assignment>().Single(a => a.Id == assignmentId).EndedAt = DateTime.UtcNow;
                db.Set<Ride>().Single(r => r.Id == rideId).DriverId = "driver-3";
                var next = new Assignment { RideId = rideId, DriverId = "driver-3" };
                db.Add(next);
                db.Add(new OutboxMessage { EventType = "ride.message.created", AggregateId = rideId,
                    Payload = JsonSerializer.Serialize(new { assignmentId, messageId = "stale-event", sequence = 2 }) });
                await db.SaveChangesAsync(); nextAssignment = next.Id;
            }
            var second = await Send(nextAssignment);
            var replacement = await newMessages.Reader.ReadAsync(timeout.Token);
            Assert.Contains(second.GetProperty("id").GetString()!, replacement.GetRawText());
            Assert.DoesNotContain("stale-event", replacement.GetRawText());
            await Task.WhenAll(NoMessage(oldMessages), NoMessage(staffMessages), NoMessage(newMessages));
        }
        finally
        {
            await timeout.CancelAsync();
            await Task.WhenAll(pumps);
        }
    }
}
