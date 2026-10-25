namespace MotoHub.Application.Marketplace;

public interface IDeliveryRealtimeNotifier
{
    Task NotifyDeliveryUpdatedAsync(DeliveryResponseDto delivery, CancellationToken cancellationToken);
}