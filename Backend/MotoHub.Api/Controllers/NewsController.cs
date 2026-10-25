using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using MotoHub.Application;
using MotoHub.Application.Marketplace;
using MotoHub.Application.News;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/news")]
public sealed class NewsController(INewsService newsService) : ControllerBase
{
    [HttpGet]
    public Task<PagedResponse<NewsSummaryResponse>> Get(
        [FromQuery] NewsListQueryDto query,
        CancellationToken cancellationToken)
        => newsService.GetFeedAsync(query, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<NewsDetailResponse> GetById(Guid id, CancellationToken cancellationToken)
        => newsService.GetByIdAsync(id, cancellationToken);

    [HttpGet("categories")]
    public Task<IReadOnlyCollection<NewsCategoryResponse>> GetCategories(CancellationToken cancellationToken)
        => newsService.GetCategoriesAsync(cancellationToken);

    [HttpPost]
    [Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
    public Task<NewsDetailResponse> Create(
        [FromBody] CreateNewsRequest request,
        CancellationToken cancellationToken)
        => newsService.CreateAsync(GetCurrentUserId(), request, cancellationToken);

    private Guid GetCurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(value, out var userId))
            throw new AuthenticationException("El sujeto autenticado no es válido.", 401);
        return userId;
    }
}