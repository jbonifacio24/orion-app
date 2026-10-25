namespace MotoHub.Application.Marketplace;

public interface IDeliveryService
{
    Task<DeliveryDriverAvailabilityResponseDto> GetDriverAvailabilityAsync(Guid driverUserId, CancellationToken cancellationToken);
    Task<DeliveryDriverEligibilityResponseDto> GetDriverEligibilityAsync(Guid driverUserId, CancellationToken cancellationToken);
    Task<DeliveryDriverAvailabilityResponseDto> UpdateDriverAvailabilityAsync(Guid driverUserId, UpdateDeliveryDriverAvailabilityRequestDto request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<NearbyDeliveryDriverResponseDto>> GetNearbyDriversAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<DeliveryResponseDto>> GetAssignedAsync(Guid driverUserId, CancellationToken cancellationToken);
    Task<DeliveryResponseDto> RequestAsync(Guid buyerUserId, Guid transactionId, CreateDeliveryRequestDto request, CancellationToken cancellationToken);
    Task<DeliveryResponseDto> GetAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken);
    Task<DeliveryResponseDto> UpdateLocationAsync(Guid sellerUserId, Guid transactionId, UpdateDeliveryLocationRequestDto request, CancellationToken cancellationToken);
    Task<DeliveryResponseDto> MarkDeliveredAsync(Guid sellerUserId, Guid transactionId, CancellationToken cancellationToken);
}
