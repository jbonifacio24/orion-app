using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.News;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.News;

public sealed class NewsService(MotoHubDbContext dbContext) : INewsService
{
    private const int MaxPageSize = 50;

    public async Task<PagedResponse<NewsSummaryResponse>> GetFeedAsync(
        NewsListQueryDto query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var now = DateTimeOffset.UtcNow;
        var news = dbContext.News
            .AsNoTracking()
            .Where(x => !x.IsDeleted &&
                        x.Status == NewsStatus.Published &&
                        x.PublishedAt != null &&
                        x.PublishedAt <= now);

        if (query.CategoryId is { } categoryId)
        {
            news = news.Where(x => x.Categories.Any(assignment =>
                assignment.NewsCategoryId == categoryId &&
                assignment.Category.IsActive &&
                !assignment.Category.IsDeleted));
        }

        var totalCount = await news.CountAsync(cancellationToken);
        var rows = await news
            .OrderByDescending(x => x.PublishedAt)
            .ThenByDescending(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .Select(x => new NewsSummaryRow
            {
                Id = x.Id,
                Slug = x.Slug,
                Title = x.Title,
                Summary = x.Summary,
                FeaturedImageUrl = x.FeaturedImageUrl,
                PublishedAt = x.PublishedAt!.Value
            })
            .ToListAsync(cancellationToken);

        var newsIds = rows.Select(x => x.Id).ToArray();
        var categoryRows = await dbContext.NewsCategoryAssignments
            .AsNoTracking()
            .Where(x => newsIds.Contains(x.NewsId) && x.Category.IsActive && !x.Category.IsDeleted)
            .OrderBy(x => x.Category.Name)
            .ThenBy(x => x.Category.Id)
            .Select(x => new NewsCategoryRow
            {
                NewsId = x.NewsId,
                Category = new NewsCategoryResponse(x.Category.Id, x.Category.Name, x.Category.Slug)
            })
            .ToListAsync(cancellationToken);

        var categoriesByNews = categoryRows
            .GroupBy(x => x.NewsId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyCollection<NewsCategoryResponse>)group.Select(x => x.Category).ToArray());
        var items = rows
            .Select(row => new NewsSummaryResponse(
                row.Id,
                row.Slug,
                row.Title,
                row.Summary,
                row.FeaturedImageUrl,
                categoriesByNews.GetValueOrDefault(row.Id) ?? Array.Empty<NewsCategoryResponse>(),
                row.PublishedAt))
            .ToArray();
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);

        return new PagedResponse<NewsSummaryResponse>(items, query.Page, query.PageSize, totalCount, totalPages);
    }

    public async Task<IReadOnlyCollection<NewsCategoryResponse>> GetCategoriesAsync(CancellationToken cancellationToken)
        => await dbContext.NewsCategories
            .AsNoTracking()
            .Where(x => x.IsActive && !x.IsDeleted)
            .OrderBy(x => x.Name)
            .ThenBy(x => x.Id)
            .Select(x => new NewsCategoryResponse(x.Id, x.Name, x.Slug))
            .ToArrayAsync(cancellationToken);

    private static void ValidateQuery(NewsListQueryDto query)
    {
        if (query.Page < 1) throw new ValidationException("Page debe ser mayor o igual que uno.");
        if (query.PageSize < 1 || query.PageSize > MaxPageSize) throw new ValidationException("PageSize debe estar entre uno y 50.");
    }

    private sealed class NewsSummaryRow
    {
        public Guid Id { get; init; }
        public string Slug { get; init; } = string.Empty;
        public string Title { get; init; } = string.Empty;
        public string? Summary { get; init; }
        public string? FeaturedImageUrl { get; init; }
        public DateTimeOffset PublishedAt { get; init; }
    }

    private sealed class NewsCategoryRow
    {
        public Guid NewsId { get; init; }
        public NewsCategoryResponse Category { get; init; } = null!;
    }
}