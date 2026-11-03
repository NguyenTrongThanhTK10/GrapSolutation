using GrapSolution.Infrastructure;
namespace GrapSolution.Api;

public sealed class PushWorker(IServiceScopeFactory factory, ILogger<PushWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(2));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try { await using var scope = factory.CreateAsyncScope(); await scope.ServiceProvider.GetRequiredService<PushDispatcher>().Process(stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception) { logger.LogWarning("Push delivery iteration failed; pending rows will be retried after their lease."); }
        }
    }
}
