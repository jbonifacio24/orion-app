using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Data.SqlClient;
using MotoHub.Application.Errors;
using MotoHub.Application.Motorcycles;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Motorcycles;

public sealed class MotorcycleService(MotoHubDbContext dbContext) : IMotorcycleService
{
    public async Task<IReadOnlyCollection<MotorcycleResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken)
    {
        var motorcycles = await dbContext.Motorcycles
            .AsNoTracking()
            .Include(x => x.Images)
            .Where(x => x.OwnerUserId == userId)
            .OrderBy(x => x.CreatedAt)
            .ThenBy(x => x.Id)
            .ToListAsync(cancellationToken);
        return motorcycles.Select(ToDto).ToArray();
    }

    public async Task<MotorcycleResponseDto> GetByIdAsync(Guid userId, Guid motorcycleId, CancellationToken cancellationToken)
    {
        var motorcycle = await QueryMine(userId, motorcycleId).SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La motocicleta no existe.");
        return ToDto(motorcycle);
    }

    public async Task<MotorcycleResponseDto> CreateAsync(Guid userId, CreateMotorcycleRequestDto request, CancellationToken cancellationToken)
    {
        Validate(request.Brand, request.Model, request.Year, request.Displacement, request.Color, request.LicensePlate, request.Vin, request.Description);
        var normalizedVin = NormalizeOptional(request.Vin);
        if (normalizedVin is not null && await dbContext.Motorcycles.AnyAsync(x => x.Vin == normalizedVin, cancellationToken))
        {
            throw new ConflictException("El VIN ya está registrado.");
        }

        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        var hasMotorcycles = await dbContext.Motorcycles.AnyAsync(x => x.OwnerUserId == userId, cancellationToken);
        var motorcycle = new Motorcycle
        {
            OwnerUserId = userId,
            Brand = request.Brand.Trim(),
            Model = request.Model.Trim(),
            Year = request.Year,
            Displacement = request.Displacement,
            Color = NormalizeOptional(request.Color),
            LicensePlate = NormalizeOptional(request.LicensePlate),
            Vin = normalizedVin,
            Description = NormalizeOptional(request.Description),
            IsPrimary = !hasMotorcycles || request.IsPrimary
        };
        if (motorcycle.IsPrimary)
        {
            await ClearPrimaryAsync(userId, null, cancellationToken);
            await SaveWithConflictHandlingAsync(cancellationToken);
        }
        dbContext.Motorcycles.Add(motorcycle);
        await SaveWithConflictHandlingAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        return ToDto(motorcycle);
    }

    public async Task<MotorcycleResponseDto> UpdateAsync(Guid userId, Guid motorcycleId, UpdateMotorcycleRequestDto request, CancellationToken cancellationToken)
    {
        Validate(request.Brand, request.Model, request.Year, request.Displacement, request.Color, request.LicensePlate, request.Vin, request.Description);
        var motorcycle = await QueryMine(userId, motorcycleId).SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La motocicleta no existe.");
        var normalizedVin = NormalizeOptional(request.Vin);
        if (normalizedVin is not null && await dbContext.Motorcycles.AnyAsync(x => x.Vin == normalizedVin && x.Id != motorcycleId, cancellationToken))
        {
            throw new ConflictException("El VIN ya está registrado.");
        }

        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        motorcycle.Brand = request.Brand.Trim();
        motorcycle.Model = request.Model.Trim();
        motorcycle.Year = request.Year;
        motorcycle.Displacement = request.Displacement;
        motorcycle.Color = NormalizeOptional(request.Color);
        motorcycle.LicensePlate = NormalizeOptional(request.LicensePlate);
        motorcycle.Vin = normalizedVin;
        motorcycle.Description = NormalizeOptional(request.Description);
        if (request.IsPrimary)
        {
            await ClearPrimaryAsync(userId, motorcycleId, cancellationToken);
            motorcycle.IsPrimary = false;
            await SaveWithConflictHandlingAsync(cancellationToken);
            motorcycle.IsPrimary = true;
        }
        await SaveWithConflictHandlingAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        return ToDto(motorcycle);
    }

    public async Task DeleteAsync(Guid userId, Guid motorcycleId, CancellationToken cancellationToken)
    {
        var motorcycle = await QueryMine(userId, motorcycleId).SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La motocicleta no existe.");
        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        var wasPrimary = motorcycle.IsPrimary;
        motorcycle.IsDeleted = true;
        motorcycle.DeletedAt = DateTimeOffset.UtcNow;
        motorcycle.IsPrimary = false;
        await SaveWithConflictHandlingAsync(cancellationToken);
        Motorcycle? replacement = null;
        if (wasPrimary)
        {
            replacement = await dbContext.Motorcycles
                .Where(x => x.OwnerUserId == userId && x.Id != motorcycleId)
                .OrderBy(x => x.CreatedAt)
                .ThenBy(x => x.Id)
                .FirstOrDefaultAsync(cancellationToken);
            if (replacement is not null) replacement.IsPrimary = true;
        }
        if (replacement is not null) await SaveWithConflictHandlingAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
    }

    private IQueryable<Motorcycle> QueryMine(Guid userId, Guid motorcycleId)
        => dbContext.Motorcycles.Include(x => x.Images).Where(x => x.OwnerUserId == userId && x.Id == motorcycleId);

    private async Task ClearPrimaryAsync(Guid userId, Guid? exceptId, CancellationToken cancellationToken)
    {
        var current = await dbContext.Motorcycles
            .Where(x => x.OwnerUserId == userId && x.IsPrimary && (!exceptId.HasValue || x.Id != exceptId.Value))
            .ToListAsync(cancellationToken);
        foreach (var motorcycle in current) motorcycle.IsPrimary = false;
    }

    private async Task SaveWithConflictHandlingAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("La operación entra en conflicto con otro registro.");
        }
        catch (DbUpdateException exception)
        {
            if (MotorcycleConflictClassifier.IsKnownUniqueConstraint(exception))
            {
                throw new ConflictException("La operación entra en conflicto con otro registro.");
            }

            throw;
        }
    }

    private async Task<IDbContextTransaction?> BeginTransactionIfRelationalAsync(CancellationToken cancellationToken)
        => dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(cancellationToken)
            : null;

    private static void Validate(string brand, string model, int year, int? displacement, string? color, string? licensePlate, string? vin, string? description)
    {
        if (string.IsNullOrWhiteSpace(brand) || brand.Length > 100) throw new ValidationException("Brand es obligatorio y debe tener como máximo 100 caracteres.");
        if (string.IsNullOrWhiteSpace(model) || model.Length > 100) throw new ValidationException("Model es obligatorio y debe tener como máximo 100 caracteres.");
        if (year is < 1885 or > 2200) throw new ValidationException("Year debe estar entre 1885 y 2200.");
        if (displacement is <= 0) throw new ValidationException("Displacement debe ser mayor que cero.");
        ValidateLength(color, 50, nameof(color));
        ValidateLength(licensePlate, 30, nameof(licensePlate));
        ValidateLength(vin, 100, nameof(vin));
        ValidateLength(description, 5000, nameof(description));
    }

    private static void ValidateLength(string? value, int maxLength, string fieldName)
    {
        if (value is not null && value.Length > maxLength) throw new ValidationException($"{fieldName} no puede superar {maxLength} caracteres.");
    }

    private static string? NormalizeOptional(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static MotorcycleResponseDto ToDto(Motorcycle motorcycle) => new(
        motorcycle.Id,
        motorcycle.Brand,
        motorcycle.Model,
        motorcycle.Year,
        motorcycle.Displacement,
        motorcycle.Color,
        motorcycle.LicensePlate,
        motorcycle.Vin,
        motorcycle.Description,
        motorcycle.IsPrimary,
        motorcycle.Images.OrderBy(x => x.DisplayOrder).ThenBy(x => x.Id).Select(x => new MotorcycleImageResponseDto(x.Id, x.Url, x.ThumbnailUrl, x.DisplayOrder, x.IsPrimary)).ToArray());
}

internal static class MotorcycleConflictClassifier
{
    public static bool IsConcurrencyConflict(DbUpdateException exception)
        => exception is DbUpdateConcurrencyException;

    public static bool IsKnownUniqueConstraint(DbUpdateException exception)
    {
        return exception.InnerException is SqlException sqlException &&
               IsKnownUniqueConstraint(sqlException.Number, sqlException.Message);
    }

    public static bool IsKnownUniqueConstraint(int sqlErrorNumber, string message)
    {
        if (sqlErrorNumber is not (2601 or 2627)) return false;

        return message.Contains("IX_Motorcycles_Vin", StringComparison.OrdinalIgnoreCase) ||
               message.Contains("IX_Motorcycles_OwnerUserId_IsPrimary", StringComparison.OrdinalIgnoreCase);
    }
}
