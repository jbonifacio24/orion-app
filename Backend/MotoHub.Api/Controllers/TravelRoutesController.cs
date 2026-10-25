using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;
using MotoHub.Application.Routes;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/travel-routes")]
public sealed class TravelRoutesController(ITravelRouteService routeService) : CurrentUserControllerBase
{
    [HttpGet]
    [AllowAnonymous]
    public Task<IReadOnlyCollection<TravelRouteResponse>> GetPublished(CancellationToken cancellationToken)
        => routeService.GetPublishedAsync(cancellationToken);

    [HttpPost]
    [Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
    public Task<TravelRouteResponse> Create(CreateTravelRouteRequest request, CancellationToken cancellationToken)
        => routeService.CreateAsync(CurrentUserId(), request, cancellationToken);

    [HttpPost("{id:guid}/join")]
    public async Task<IActionResult> Join(Guid id, CancellationToken cancellationToken)
        => Ok(new { conversationId = await routeService.JoinChatAsync(CurrentUserId(), id, cancellationToken) });

    [HttpDelete("{id:guid}")]
    [Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await routeService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }
}
