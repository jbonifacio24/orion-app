using MotoHub.Domain;

namespace MotoHub.Application.Marketplace;

public sealed record CreateDeliveryRequestDto(decimal DestinationLatitude, decimal DestinationLongitude, Guid DriverUserId);
public sealed record UpdateDeliveryLocationRequestDto(decimal Latitude, decimal Longitude);
public sealed record UpdateDeliveryDriverAvailabilityRequestDto(decimal? Latitude, decimal? Longitude, bool IsAvailable);
public sealed record DeliveryDriverAvailabilityResponseDto(bool IsAvailable, DateTimeOffset UpdatedAt);
public sealed record DeliveryDriverEligibilityResponseDto(bool IsEligible, bool EmailConfirmed, bool HasFullName, bool HasPhoneNumber, bool HasQualifiedMotorcycle);
public sealed record NearbyDeliveryDriverResponseDto(Guid UserId, string DisplayName, decimal DistanceInKm);
public sealed record DeliveryResponseDto(Guid Id, Guid ProductTransactionId, Guid SellerUserId, Guid? DriverUserId, decimal? PickupLatitude, decimal? PickupLongitude, decimal DestinationLatitude, decimal DestinationLongitude, decimal? DriverLatitude, decimal? DriverLongitude, DeliveryStatus Status);
