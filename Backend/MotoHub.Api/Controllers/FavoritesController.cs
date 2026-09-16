using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/favorites")]
public sealed class FavoritesController(IFavoriteService favoriteService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<IReadOnlyCollection<ProductResponseDto>> Get(CancellationToken cancellationToken)
        => favoriteService.GetMineAsync(CurrentUserId(), cancellationToken);

    [HttpPost("/api/products/{id:guid}/favorite")]
    public async Task<IActionResult> Add(Guid id, CancellationToken cancellationToken)
    {
        await favoriteService.AddAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }

    [HttpDelete("/api/products/{id:guid}/favorite")]
    public async Task<IActionResult> Remove(Guid id, CancellationToken cancellationToken)
    {
        await favoriteService.RemoveAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }
}
