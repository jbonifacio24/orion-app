using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.News;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using NewsEntity = MotoHub.Domain.News;

namespace MotoHub.Infrastructure.News;

public sealed class NewsService(MotoHubDbContext dbContext) : INewsService
{
    private const int MaxPageSize = 50;
    private const int MaxTitleLength = 250;
    private const int MaxSummaryLength = 1000;
    private const int MaxContentLength = 50000;

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

    public async Task<NewsDetailResponse> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var row = await dbContext.News
            .AsNoTracking()
            .Where(x => x.Id == id &&
                        !x.IsDeleted &&
                        x.Status == NewsStatus.Published &&
                        x.PublishedAt != null &&
                        x.PublishedAt <= now)
            .Select(x => new NewsDetailRow
            {
                Id = x.Id,
                Slug = x.Slug,
                Title = x.Title,
                Summary = x.Summary,
                Content = x.Content,
                FeaturedImageUrl = x.FeaturedImageUrl,
                PublishedAt = x.PublishedAt!.Value
            })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La noticia no existe.");

        var categories = await dbContext.NewsCategoryAssignments
            .AsNoTracking()
            .Where(x => x.NewsId == row.Id && x.Category.IsActive && !x.Category.IsDeleted)
            .OrderBy(x => x.Category.Name)
            .ThenBy(x => x.Category.Id)
            .Select(x => new NewsCategoryResponse(x.Category.Id, x.Category.Name, x.Category.Slug))
            .ToArrayAsync(cancellationToken);

        return new NewsDetailResponse(
            row.Id,
            row.Slug,
            row.Title,
            row.Summary,
            row.Content,
            row.FeaturedImageUrl,
            categories,
            row.PublishedAt);
    }

    public async Task<IReadOnlyCollection<NewsCategoryResponse>> GetCategoriesAsync(CancellationToken cancellationToken)
        => await dbContext.NewsCategories
            .AsNoTracking()
            .Where(x => x.IsActive && !x.IsDeleted)
            .OrderBy(x => x.Name)
            .ThenBy(x => x.Id)
            .Select(x => new NewsCategoryResponse(x.Id, x.Name, x.Slug))
            .ToArrayAsync(cancellationToken);

    public async Task<NewsDetailResponse> CreateAsync(
        Guid authorUserId,
        CreateNewsRequest request,
        CancellationToken cancellationToken)
    {
        var title = NormalizeRequired(request.Title, MaxTitleLength, "El título es obligatorio.");
        var content = NormalizeRequired(request.Content, MaxContentLength, "El contenido es obligatorio.");
        var summary = NormalizeOptional(request.Summary, MaxSummaryLength);
        var imageUrl = NormalizeOptional(request.FeaturedImageUrl, 2000);
        var slug = await CreateUniqueSlugAsync(title, cancellationToken);
        var news = new NewsEntity
        {
            AuthorUserId = authorUserId,
            Title = title,
            Slug = slug,
            Summary = summary,
            Content = content,
            FeaturedImageUrl = imageUrl,
            Status = NewsStatus.Published,
            PublishedAt = DateTimeOffset.UtcNow
        };

        var categoryIds = (request.CategoryIds ?? Array.Empty<Guid>()).Distinct().ToArray();
        if (categoryIds.Length > 0)
        {
            var validCategoryIds = await dbContext.NewsCategories
                .Where(x => categoryIds.Contains(x.Id) && x.IsActive && !x.IsDeleted)
                .Select(x => x.Id)
                .ToArrayAsync(cancellationToken);
            if (validCategoryIds.Length != categoryIds.Length)
                throw new ValidationException("Una o más categorías no son válidas.");
            foreach (var categoryId in validCategoryIds)
                news.Categories.Add(new NewsCategoryAssignment { NewsCategoryId = categoryId });
        }

        dbContext.News.Add(news);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(news.Id, cancellationToken);
    }

    private async Task<string> CreateUniqueSlugAsync(string title, CancellationToken cancellationToken)
    {
        var baseSlug = Slugify(title);
        var slug = baseSlug;
        var suffix = 2;
        while (await dbContext.News.IgnoreQueryFilters().AnyAsync(x => x.Slug == slug, cancellationToken))
            slug = $"{baseSlug}-{suffix++}";
        return slug;
    }

    private static string NormalizeRequired(string? value, int maxLength, string emptyMessage)
    {
        var normalized = value?.Trim() ?? string.Empty;
        if (normalized.Length == 0) throw new ValidationException(emptyMessage);
        if (normalized.Length > maxLength) throw new ValidationException($"El texto no puede superar los {maxLength} caracteres.");
        return normalized;
    }

    private static string? NormalizeOptional(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrWhiteSpace(normalized)) return null;
        if (normalized.Length > maxLength) throw new ValidationException($"El texto no puede superar los {maxLength} caracteres.");
        return normalized;
    }

    private static string Slugify(string value)
    {
        var normalized = value.Normalize(System.Text.NormalizationForm.FormD);
        var builder = new System.Text.StringBuilder();
        foreach (var character in normalized)
        {
            var category = System.Globalization.CharUnicodeInfo.GetUnicodeCategory(character);
            if (category == System.Globalization.UnicodeCategory.NonSpacingMark) continue;
            builder.Append(char.IsLetterOrDigit(character) ? char.ToLowerInvariant(character) : '-');
        }
        var slug = System.Text.RegularExpressions.Regex.Replace(builder.ToString(), "-+", "-").Trim('-');
        return string.IsNullOrEmpty(slug) ? $"noticia-{Guid.NewGuid():N}" : slug;
    }

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

    private sealed class NewsDetailRow
    {
        public Guid Id { get; init; }
        public string Slug { get; init; } = string.Empty;
        public string Title { get; init; } = string.Empty;
        public string? Summary { get; init; }
        public string Content { get; init; } = string.Empty;
        public string? FeaturedImageUrl { get; init; }
        public DateTimeOffset PublishedAt { get; init; }
    }

    private sealed class NewsCategoryRow
    {
        public Guid NewsId { get; init; }
        public NewsCategoryResponse Category { get; init; } = null!;
    }
}