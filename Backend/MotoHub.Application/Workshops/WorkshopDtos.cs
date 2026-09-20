using MotoHub.Application.Marketplace;

namespace MotoHub.Application.Workshops;

public sealed record WorkshopListQueryDto(
    string? Search = null,
    string? City = null,
    int Page = 1,
    int PageSize = 20);

public sealed record WorkshopListItemDto(
    Guid Id,
    string Name,
    string? Description,
    string? Address,
    string? City,
    decimal? Latitude,
    decimal? Longitude,
    decimal? AverageRating,
    int ReviewCount);

public sealed record WorkshopScheduleResponseDto(
    Guid Id,
    int DayOfWeek,
    TimeOnly? OpenTime,
    TimeOnly? CloseTime,
    bool IsClosed);

public sealed record WorkshopServiceResponseDto(
    Guid Id,
    string Name,
    string? Description,
    decimal? Price,
    int? DurationMinutes);

public sealed record WorkshopReviewResponseDto(
    Guid Id,
    int Rating,
    string? Comment,
    DateTimeOffset CreatedAt);

public sealed record WorkshopDetailResponseDto(
    Guid Id,
    string Name,
    string? Description,
    string? PhoneNumber,
    string? Email,
    string? Address,
    string? City,
    decimal? Latitude,
    decimal? Longitude,
    DateTimeOffset? VerifiedAt,
    IReadOnlyCollection<WorkshopScheduleResponseDto> Schedules,
    IReadOnlyCollection<WorkshopServiceResponseDto> Services,
    IReadOnlyCollection<WorkshopReviewResponseDto> Reviews,
    decimal? AverageRating,
    int ReviewCount);