using MotoHub.Application.Marketplace;

namespace MotoHub.Application.News;

public interface INewsService
{
    Task<PagedResponse<NewsSummaryResponse>> GetFeedAsync(NewsListQueryDto query, CancellationToken cancellationToken);
    Task<NewsDetailResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<NewsCategoryResponse>> GetCategoriesAsync(CancellationToken cancellationToken);
}