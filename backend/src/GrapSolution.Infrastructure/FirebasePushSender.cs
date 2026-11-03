using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using GrapSolution.Application;

namespace GrapSolution.Infrastructure;

public sealed class FirebasePushSender : IPushSender, IDisposable
{
    private readonly FirebaseApp? app;
    public bool Enabled => app != null;
    public FirebasePushSender(bool enabled, string projectId)
    {
        if (!enabled) return;
        if (string.IsNullOrWhiteSpace(projectId)) throw new InvalidOperationException("Firebase:ProjectId is required when push is enabled.");
        // ADC supports GOOGLE_APPLICATION_CREDENTIALS and workload identity. Credentials never enter mobile apps.
        app = FirebaseApp.Create(new AppOptions { Credential = GoogleCredential.GetApplicationDefault(), ProjectId = projectId }, "grap-" + Guid.NewGuid());
    }
    public async Task<PushSendResult> Send(PushPayload payload, CancellationToken ct)
    {
        if (app == null) return PushSendResult.Retry("PUSH_DISABLED");
        try
        {
            await FirebaseMessaging.GetMessaging(app).SendAsync(new Message
            {
#pragma warning disable CS0618 // Flutter getToken returns an FCM registration token, not a Firebase Installation ID. FCM v1 still supports this target.
                Token = payload.Token,
#pragma warning restore CS0618
                Notification = new FirebaseAdmin.Messaging.Notification { Title = payload.Title, Body = payload.Body },
                Data = payload.Data.ToDictionary(p => p.Key, p => p.Value),
                Android = new AndroidConfig { Priority = Priority.High, TimeToLive = payload.Ttl, Notification = new AndroidNotification { ChannelId = "grap_updates", Icon = "ic_stat_grap", Sound = "default", Tag = payload.Data.GetValueOrDefault("notificationId") } },
                Apns = new ApnsConfig { Headers = new Dictionary<string, string> { ["apns-expiration"] = DateTimeOffset.UtcNow.Add(payload.Ttl).ToUnixTimeSeconds().ToString() }, Aps = new Aps { Sound = "default" } },
            }, ct);
            return PushSendResult.Sent();
        }
        catch (FirebaseMessagingException ex)
        {
            // Only UNREGISTERED proves this registration is no longer valid. Other 400s can be payload/config issues.
            return ex.MessagingErrorCode switch
            {
                MessagingErrorCode.Unregistered => new("INVALID_TOKEN", "UNREGISTERED"),
                MessagingErrorCode.InvalidArgument or MessagingErrorCode.SenderIdMismatch or MessagingErrorCode.ThirdPartyAuthError => new("FAILED", ex.MessagingErrorCode.ToString()),
                MessagingErrorCode.QuotaExceeded => PushSendResult.Retry("QUOTA_EXCEEDED", TimeSpan.FromMinutes(1)),
                _ => PushSendResult.Retry(ex.MessagingErrorCode?.ToString() ?? "FCM_UNAVAILABLE"),
            };
        }
    }
    public void Dispose() => app?.Delete();
}
