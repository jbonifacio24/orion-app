using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;
using SkiaSharp;
using MotoHub.Application.Errors;
using MotoHub.Application.Motorcycles;
using MotoHub.Application.Storage;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Storage;

namespace MotoHub.Infrastructure.Motorcycles;

public sealed class MotorcycleImageService(
    MotoHubDbContext dbContext,
    IMotorcycleImageStorage storage,
    ImageFileValidator validator,
    ILogger<MotorcycleImageService> logger) : IMotorcycleImageService
{
    private const int MaxImages = 3;
    private const int MaxDimension = 1600;
    private const int JpegQuality = 80;

    public async Task<MotorcycleImageResponseDto> UploadAsync(Guid userId, Guid motorcycleId, UploadMotorcycleImageRequest request, CancellationToken cancellationToken)
    {
        await validator.ValidateAsync(request.Content, request.FileName, request.ContentType, request.Length, cancellationToken);
        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        var motorcycle = await dbContext.Motorcycles.Include(x => x.Images)
            .SingleOrDefaultAsync(x => x.Id == motorcycleId && x.OwnerUserId == userId && !x.IsDeleted, cancellationToken)
            ?? throw new ResourceNotFoundException("La motocicleta no existe.");
        if (motorcycle.Images.Count >= MaxImages) throw new ConflictException("La motocicleta puede tener como máximo 3 imágenes.");

        using var compressed = Compress(request.Content, cancellationToken);
        var displayOrder = motorcycle.Images.Count == 0 ? 0 : motorcycle.Images.Max(x => x.DisplayOrder) + 1;
        var image = new MotorcycleImage { MotorcycleId = motorcycleId, StorageKey = string.Empty, Url = string.Empty, DisplayOrder = displayOrder, IsPrimary = motorcycle.Images.Count == 0 };
        string? storageKey = null;
        try
        {
            var stored = await storage.SaveAsync(motorcycleId, compressed, cancellationToken);
            storageKey = stored.StorageKey;
            image.StorageKey = stored.StorageKey;
            image.Url = stored.Url;
            dbContext.MotorcycleImages.Add(image);
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null) await transaction.CommitAsync(cancellationToken);
            return ToDto(image);
        }
        catch
        {
            if (transaction is not null) await transaction.RollbackAsync(CancellationToken.None);
            if (storageKey is not null)
            {
                try { await storage.DeleteAsync(storageKey, CancellationToken.None); }
                catch (Exception cleanupError) { logger.LogError(cleanupError, "Failed to clean up motorcycle image after database failure."); }
            }
            throw;
        }
    }

    public async Task DeleteAsync(Guid userId, Guid motorcycleId, Guid imageId, CancellationToken cancellationToken)
    {
        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        var motorcycle = await dbContext.Motorcycles.Include(x => x.Images)
            .SingleOrDefaultAsync(x => x.Id == motorcycleId && x.OwnerUserId == userId && !x.IsDeleted, cancellationToken)
            ?? throw new ResourceNotFoundException("La motocicleta no existe.");
        var image = motorcycle.Images.SingleOrDefault(x => x.Id == imageId)
            ?? throw new ResourceNotFoundException("La imagen no existe.");
        var storageKey = image.StorageKey;
        dbContext.MotorcycleImages.Remove(image);
        var remaining = motorcycle.Images.Where(x => x.Id != imageId).OrderBy(x => x.DisplayOrder).ThenBy(x => x.Id).ToArray();
        for (var index = 0; index < remaining.Length; index++)
        {
            remaining[index].DisplayOrder = index;
            remaining[index].IsPrimary = image.IsPrimary && index == 0 || !remaining.Any(x => x.IsPrimary) && index == 0;
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null) await transaction.CommitAsync(cancellationToken);
        try { await storage.DeleteAsync(storageKey, CancellationToken.None); }
        catch (Exception cleanupError) { logger.LogError(cleanupError, "Failed to clean up deleted motorcycle image."); }
    }

    private static MemoryStream Compress(Stream content, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        content.Position = 0;
        using var image = SKBitmap.Decode(content) ?? throw new InvalidDataException("The uploaded file is not a supported image.");
        var scale = Math.Min(1d, Math.Min((double)MaxDimension / image.Width, (double)MaxDimension / image.Height));
        var resizedInfo = new SKImageInfo(
            Math.Max(1, (int)Math.Round(image.Width * scale)),
            Math.Max(1, (int)Math.Round(image.Height * scale)));
        using var resized = image.Resize(resizedInfo, new SKSamplingOptions(SKFilterMode.Linear))
            ?? throw new InvalidDataException("The uploaded image could not be resized.");
        using var encoded = resized.Encode(SKEncodedImageFormat.Jpeg, JpegQuality);
        var output = new MemoryStream();
        encoded.SaveTo(output);
        output.Position = 0;
        return output;
    }

    private async Task<IDbContextTransaction?> BeginTransactionIfRelationalAsync(CancellationToken cancellationToken)
        => dbContext.Database.IsRelational() ? await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken) : null;

    private static MotorcycleImageResponseDto ToDto(MotorcycleImage image)
        => new(image.Id, image.Url, image.ThumbnailUrl, image.DisplayOrder, image.IsPrimary);
}
