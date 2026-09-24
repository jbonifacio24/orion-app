using MotoHub.Application.Marketplace;
using MotoHub.Domain;

namespace MotoHub.Application.TheftReports;

public interface ITheftReportService
{
    Task<PagedResponse<TheftReportResponseDto>> GetActiveAsync(TheftReportListQueryDto query, CancellationToken cancellationToken);
    Task<TheftReportResponseDto> GetByIdAsync(Guid userId, Guid reportId, CancellationToken cancellationToken);
    Task<PagedResponse<TheftReportResponseDto>> GetMineAsync(Guid userId, TheftReportListQueryDto query, CancellationToken cancellationToken);
    Task<TheftReportResponseDto> CreateAsync(Guid userId, CreateTheftReportRequestDto request, CancellationToken cancellationToken);
    Task<TheftReportResponseDto> UpdateStatusAsync(Guid userId, Guid reportId, UpdateTheftReportStatusRequestDto request, CancellationToken cancellationToken);
}

public sealed record TheftReportListQueryDto(
    TheftReportStatus? Status = null,
    string? Search = null,
    int Page = 1,
    int PageSize = 20);

public sealed record CreateTheftReportRequestDto(
    Guid? MotorcycleId,
    string Title,
    string Description,
    string? LicensePlate,
    string? Vin,
    string? Brand,
    string? Model,
    string? Color,
    DateTimeOffset TheftDate,
    string? TheftLocation,
    decimal? Latitude,
    decimal? Longitude);

public sealed record UpdateTheftReportStatusRequestDto(TheftReportStatus Status);

public sealed record TheftReportResponseDto(
    Guid Id,
    Guid? MotorcycleId,
    string Title,
    string Description,
    string? LicensePlate,
    string? Vin,
    string? Brand,
    string? Model,
    string? Color,
    DateTimeOffset TheftDate,
    string? TheftLocation,
    decimal? Latitude,
    decimal? Longitude,
    TheftReportStatus Status,
    DateTimeOffset? ResolvedAt,
    DateTimeOffset CreatedAt);