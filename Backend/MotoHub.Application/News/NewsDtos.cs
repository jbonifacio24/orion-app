using MotoHub.Application.Marketplace;

namespace MotoHub.Application.News;

public sealed record NewsListQueryDto(
    int Page = 1,
    int PageSize = 20,
    Guid? CategoryId = null);

public sealed record NewsCategoryResponse(
    Guid Id,
    string Name,
    string Slug);

public sealed record NewsSummaryResponse(
    Guid Id,
    string Slug,
    string Title,
    string? Summary,
    string? FeaturedImageUrl,
    IReadOnlyCollection<NewsCategoryResponse> Categories,
    DateTimeOffset PublishedAt);

public sealed record NewsDetailResponse(
    Guid Id,
    string Slug,
    string Title,
    string? Summary,
    string Content,
    string? FeaturedImageUrl,
    IReadOnlyCollection<NewsCategoryResponse> Categories,
    DateTimeOffset PublishedAt);