using Microsoft.AspNetCore.SignalR;
using MotoHub.Api.Hubs;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Realtime;

public sealed class SignalRDeliveryRealtimeNotifier(IHubContext<DeliveryHub> hubContext) : IDeliveryRealtimeNotifier
{
    public Task NotifyDeliveryUpdatedAsync(DeliveryResponseDto delivery, CancellationToken cancellationToken)
        => hubContext.Clients
            .Group(DeliveryGroupNames.Transaction(delivery.ProductTransactionId))
            .SendAsync("DeliveryUpdated", delivery, cancellationToken);
}