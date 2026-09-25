using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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

    [HttpGet("categories")]
    public Task<IReadOnlyCollection<NewsCategoryResponse>> GetCategories(CancellationToken cancellationToken)
        => newsService.GetCategoriesAsync(cancellationToken);
}