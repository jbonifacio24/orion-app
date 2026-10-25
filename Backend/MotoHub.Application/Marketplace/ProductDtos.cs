using MotoHub.Domain;

namespace MotoHub.Application.Marketplace;

public sealed record ProductImageResponseDto(
    Guid Id,
    string Url,
    string? ThumbnailUrl,
    int DisplayOrder,
    bool IsPrimary);

public sealed record SellerSummaryDto(
    Guid Id,
    string UserName,
    string? DisplayName,
    string? ProfileImageUrl,
    int SuccessfulSales = 0,
    decimal AverageRating = 0,
    int RatingCount = 0);

public sealed record ProductCategoryResponseDto(
    Guid Id,
    Guid? ParentCategoryId,
    string Name,
    string Slug,
    string? Description,
    int DisplayOrder,
    bool IsActive);

public sealed record ProductResponseDto(
    Guid Id,
    Guid CategoryId,
    string Name,
    string Description,
    decimal? Price,
    string? Currency,
    int? StockQuantity,
    ProductCondition Condition,
    ProductStatus Status,
    string? Location,
    DateTimeOffset? PublishedAt,
    DateTimeOffset CreatedAt,
    string RowVersion,
    IReadOnlyCollection<ProductImageResponseDto> Images,
    decimal? Latitude = null,
    decimal? Longitude = null,
    string? PaymentMethod = null);

public sealed record ProductDetailResponseDto(
    Guid Id,
    Guid CategoryId,
    string Name,
    string Description,
    decimal? Price,
    string? Currency,
    int? StockQuantity,
    ProductCondition Condition,
    ProductStatus Status,
    string? Location,
    DateTimeOffset? PublishedAt,
    DateTimeOffset CreatedAt,
    string RowVersion,
    ProductCategoryResponseDto Category,
    SellerSummaryDto Seller,
    IReadOnlyCollection<ProductImageResponseDto> Images,
    bool IsFavorite,
    bool IsOwner,
    decimal? Latitude = null,
    decimal? Longitude = null,
    string? PaymentMethod = null);

public sealed record CreateProductRequestDto(
    Guid CategoryId,
    string Name,
    string Description,
    decimal? Price,
    string? Currency,
    int? StockQuantity,
    ProductCondition Condition,
    string? Location,
    decimal? Latitude = null,
    decimal? Longitude = null,
    string? PaymentMethod = null);

public sealed record UpdateProductRequestDto(
    Guid CategoryId,
    string Name,
    string Description,
    decimal? Price,
    string? Currency,
    int? StockQuantity,
    ProductCondition Condition,
    string? Location,
    string ExpectedRowVersion,
    decimal? Latitude = null,
    decimal? Longitude = null,
    string? PaymentMethod = null);

public sealed record ProductListQueryDto(
    string? Search = null,
    Guid? CategoryId = null,
    decimal? MinPrice = null,
    decimal? MaxPrice = null,
    ProductCondition? Condition = null,
    string? Sort = null,
    int Page = 1,
    int PageSize = 20);
