using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/delivery")]
public sealed class DeliveryDriversController(IDeliveryService deliveryService) : CurrentUserControllerBase
{
    [HttpGet("driver-availability")]
    public Task<DeliveryDriverAvailabilityResponseDto> GetAvailability(CancellationToken cancellationToken)
        => deliveryService.GetDriverAvailabilityAsync(CurrentUserId(), cancellationToken);

    [HttpGet("driver-eligibility")]
    public Task<DeliveryDriverEligibilityResponseDto> GetEligibility(CancellationToken cancellationToken)
        => deliveryService.GetDriverEligibilityAsync(CurrentUserId(), cancellationToken);

    [HttpPut("driver-availability")]
    public Task<DeliveryDriverAvailabilityResponseDto> UpdateAvailability(UpdateDeliveryDriverAvailabilityRequestDto request, CancellationToken cancellationToken)
        => deliveryService.UpdateDriverAvailabilityAsync(CurrentUserId(), request, cancellationToken);

    [HttpGet("assigned")]
    public Task<IReadOnlyCollection<DeliveryResponseDto>> GetAssigned(CancellationToken cancellationToken)
        => deliveryService.GetAssignedAsync(CurrentUserId(), cancellationToken);
}