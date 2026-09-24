using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.TheftReports;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.TheftReports;

public sealed class TheftReportService(MotoHubDbContext dbContext) : ITheftReportService
{
    private const int MaxPageSize = 50;

    public async Task<PagedResponse<TheftReportResponseDto>> GetActiveAsync(TheftReportListQueryDto query, CancellationToken cancellationToken)
    {
        ValidateQuery(query, allowResolvedStatuses: false);
        var reports = ApplyFilters(dbContext.TheftReports.AsNoTracking(), query)
            .Where(x => x.Status == TheftReportStatus.Reported || x.Status == TheftReportStatus.Investigating);
        return await PageAsync(reports, query, cancellationToken);
    }

    public async Task<TheftReportResponseDto> GetByIdAsync(Guid userId, Guid reportId, CancellationToken cancellationToken)
    {
        var report = await dbContext.TheftReports.AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == reportId, cancellationToken)
            ?? throw new ResourceNotFoundException("El reporte de robo no existe.");

        var isOwner = report.ReporterUserId == userId;
        if (!isOwner && report.Status is not (TheftReportStatus.Reported or TheftReportStatus.Investigating))
        {
            throw new ResourceNotFoundException("El reporte de robo no existe.");
        }

        return ToDto(report);
    }

    public async Task<PagedResponse<TheftReportResponseDto>> GetMineAsync(Guid userId, TheftReportListQueryDto query, CancellationToken cancellationToken)
    {
        ValidateQuery(query, allowResolvedStatuses: true);
        var reports = ApplyFilters(dbContext.TheftReports.AsNoTracking(), query)
            .Where(x => x.ReporterUserId == userId);
        return await PageAsync(reports, query, cancellationToken);
    }

    public async Task<TheftReportResponseDto> CreateAsync(Guid userId, CreateTheftReportRequestDto request, CancellationToken cancellationToken)
    {
        var normalized = ValidateAndNormalize(request);
        if (request.MotorcycleId.HasValue)
        {
            var motorcycle = await dbContext.Motorcycles.AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == request.MotorcycleId.Value && x.OwnerUserId == userId, cancellationToken)
                ?? throw new ResourceNotFoundException("La motocicleta no existe.");

            normalized = normalized with
            {
                LicensePlate = NormalizeOptional(motorcycle.LicensePlate),
                Vin = NormalizeOptional(motorcycle.Vin),
                Brand = motorcycle.Brand,
                Model = motorcycle.Model,
                Color = NormalizeOptional(motorcycle.Color)
            };
        }
        else
        {
            ValidateManualVehicle(normalized.Brand, normalized.Model, normalized.LicensePlate, normalized.Vin);
        }

        var report = new TheftReport
        {
            ReporterUserId = userId,
            MotorcycleId = request.MotorcycleId,
            Title = normalized.Title,
            Description = normalized.Description,
            LicensePlate = normalized.LicensePlate,
            Vin = normalized.Vin,
            Brand = normalized.Brand,
            Model = normalized.Model,
            Color = normalized.Color,
            TheftDate = request.TheftDate,
            TheftLocation = normalized.TheftLocation,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            Status = TheftReportStatus.Reported
        };
        dbContext.TheftReports.Add(report);
        await SaveAsync(cancellationToken);
        return ToDto(report);
    }

    public async Task<TheftReportResponseDto> UpdateStatusAsync(Guid userId, Guid reportId, UpdateTheftReportStatusRequestDto request, CancellationToken cancellationToken)
    {
        if (request.Status is not (TheftReportStatus.Recovered or TheftReportStatus.Closed))
        {
            throw new ValidationException("Status solo puede ser Recovered o Closed.");
        }

        var report = await dbContext.TheftReports
            .SingleOrDefaultAsync(x => x.Id == reportId && x.ReporterUserId == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("El reporte de robo no existe.");
        if (report.Status is TheftReportStatus.Recovered or TheftReportStatus.Closed)
        {
            throw new ConflictException("El reporte de robo ya está resuelto.");
        }
        report.Status = request.Status;
        report.ResolvedAt = DateTimeOffset.UtcNow;
        await SaveAsync(cancellationToken);
        return ToDto(report);
    }

    private static IQueryable<TheftReport> ApplyFilters(IQueryable<TheftReport> reports, TheftReportListQueryDto query)
    {
        if (query.Status.HasValue) reports = reports.Where(x => x.Status == query.Status.Value);
        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var search = query.Search.Trim();
            reports = reports.Where(x => x.Title.Contains(search) ||
                                         x.Description.Contains(search) ||
                                         (x.Brand != null && x.Brand.Contains(search)) ||
                                         (x.Model != null && x.Model.Contains(search)) ||
                                         (x.LicensePlate != null && x.LicensePlate.Contains(search)));
        }
        return reports;
    }

    private static async Task<PagedResponse<TheftReportResponseDto>> PageAsync(IQueryable<TheftReport> reports, TheftReportListQueryDto query, CancellationToken cancellationToken)
    {
        var totalCount = await reports.CountAsync(cancellationToken);
        var items = await reports.OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize).Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<TheftReportResponseDto>(items.Select(ToDto).ToArray(), query.Page, query.PageSize, totalCount, totalPages);
    }

    private static NormalizedRequest ValidateAndNormalize(CreateTheftReportRequestDto request)
    {
        var title = request.Title?.Trim() ?? string.Empty;
        var description = request.Description?.Trim() ?? string.Empty;
        var licensePlate = NormalizeOptional(request.LicensePlate);
        var vin = NormalizeOptional(request.Vin);
        var brand = NormalizeOptional(request.Brand);
        var model = NormalizeOptional(request.Model);
        var color = NormalizeOptional(request.Color);
        var theftLocation = NormalizeOptional(request.TheftLocation);
        if (string.IsNullOrWhiteSpace(title) || title.Length > 200) throw new ValidationException("Title es obligatorio y debe tener como máximo 200 caracteres.");
        if (string.IsNullOrWhiteSpace(description) || description.Length > 10000) throw new ValidationException("Description es obligatoria y debe tener como máximo 10000 caracteres.");
        if (request.TheftDate > DateTimeOffset.UtcNow) throw new ValidationException("TheftDate no puede estar en el futuro.");
        if (request.Latitude.HasValue != request.Longitude.HasValue) throw new ValidationException("Latitude y Longitude deben enviarse juntas.");
        if (request.Latitude is < -90 or > 90 || request.Longitude is < -180 or > 180) throw new ValidationException("Las coordenadas no son válidas.");
        ValidateLength(licensePlate, 30, "LicensePlate");
        ValidateLength(vin, 100, "Vin");
        ValidateLength(brand, 100, "Brand");
        ValidateLength(model, 100, "Model");
        ValidateLength(color, 50, "Color");
        ValidateLength(theftLocation, 500, "TheftLocation");
        return new NormalizedRequest(title, description, licensePlate, vin, brand, model, color, theftLocation);
    }

    private static void ValidateManualVehicle(string? brand, string? model, string? licensePlate, string? vin)
    {
        if (string.IsNullOrWhiteSpace(brand) || string.IsNullOrWhiteSpace(model)) throw new ValidationException("Brand y Model son obligatorios cuando no se vincula una motocicleta.");
        if (string.IsNullOrWhiteSpace(licensePlate) && string.IsNullOrWhiteSpace(vin)) throw new ValidationException("LicensePlate o Vin es obligatorio cuando no se vincula una motocicleta.");
    }

    private static void ValidateQuery(TheftReportListQueryDto query, bool allowResolvedStatuses)
    {
        if (query.Page < 1 || query.PageSize < 1 || query.PageSize > MaxPageSize) throw new ValidationException($"Page debe ser mayor o igual que uno y PageSize debe estar entre uno y {MaxPageSize}.");
        if (query.Search?.Length > 200) throw new ValidationException("Search no puede superar 200 caracteres.");
        if (query.Status.HasValue && !Enum.IsDefined(typeof(TheftReportStatus), query.Status.Value)) throw new ValidationException("Status no es válido.");
        if (!allowResolvedStatuses && query.Status is TheftReportStatus.Recovered or TheftReportStatus.Closed) throw new ValidationException("Status debe ser Reported o Investigating.");
    }

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        try { await dbContext.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateConcurrencyException) { throw new ConflictException("La operación entra en conflicto con otro registro."); }
    }

    private static TheftReportResponseDto ToDto(TheftReport report) => new(
        report.Id, report.MotorcycleId, report.Title, report.Description, report.LicensePlate, MaskVin(report.Vin), report.Brand, report.Model,
        report.Color, report.TheftDate, report.TheftLocation, report.Latitude, report.Longitude, report.Status, report.ResolvedAt, report.CreatedAt);

    private static string? MaskVin(string? vin) => string.IsNullOrWhiteSpace(vin) ? null : vin.Length <= 4 ? "****" : new string('*', vin.Length - 4) + vin[^4..];
    private static void ValidateLength(string? value, int maxLength, string field) { if (value?.Length > maxLength) throw new ValidationException($"{field} no puede superar {maxLength} caracteres."); }
    private static string? NormalizeOptional(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private sealed record NormalizedRequest(string Title, string Description, string? LicensePlate, string? Vin, string? Brand, string? Model, string? Color, string? TheftLocation);
}