using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Storage;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Storage;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class ProductImageService(
    MotoHubDbContext dbContext,
    IProductImageStorage storage,
    ImageFileValidator validator,
    IOptions<ProductImageStorageOptions> options,
    ILogger<ProductImageService> logger) : IProductImageService
{
    public async Task<ProductImageResponseDto> UploadAsync(Guid userId, Guid productId, UploadProductImageRequest request, CancellationToken cancellationToken)
    {
        var extension = await validator.ValidateAsync(request.Content, request.FileName, request.ContentType, request.Length, cancellationToken);
        await using var transaction = await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        var product = await dbContext.Products.Include(x => x.Images).SingleOrDefaultAsync(x => x.Id == productId && x.SellerUserId == userId && !x.IsDeleted, cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");
        if (product.Images.Count >= options.Value.MaxImagesPerProduct) throw new ConflictException("El producto alcanzó el máximo de imágenes.");

        var displayOrder = product.Images.Count == 0 ? 0 : product.Images.Max(x => x.DisplayOrder) + 1;
        var image = new ProductImage { ProductId = productId, StorageKey = string.Empty, Url = string.Empty, DisplayOrder = displayOrder, IsPrimary = product.Images.Count == 0 };
        string? storageKey = null;
        try
        {
            var stored = await storage.SaveAsync(productId, request.Content, extension, cancellationToken);
            storageKey = stored.StorageKey;
            image.StorageKey = stored.StorageKey;
            image.Url = stored.Url;
            image.ThumbnailUrl = null;
            dbContext.ProductImages.Add(image);
            await SaveAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            return ToDto(image);
        }
        catch
        {
            await transaction.RollbackAsync(CancellationToken.None);
            if (storageKey is not null)
            {
                try { await storage.DeleteAsync(storageKey, CancellationToken.None); }
                catch (Exception cleanupError) { logger.LogError(cleanupError, "Failed to clean up product image after database failure."); }
            }
            throw;
        }
    }

    public async Task DeleteAsync(Guid userId, Guid productId, Guid imageId, CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        var product = await dbContext.Products.Include(x => x.Images).SingleOrDefaultAsync(x => x.Id == productId && x.SellerUserId == userId && !x.IsDeleted, cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");
        var image = product.Images.SingleOrDefault(x => x.Id == imageId)
            ?? throw new ResourceNotFoundException("La imagen no existe.");
        var storageKey = image.StorageKey;
        dbContext.ProductImages.Remove(image);
        var remaining = product.Images.Where(x => x.Id != imageId).OrderBy(x => x.DisplayOrder).ThenBy(x => x.Id).ToArray();
        for (var index = 0; index < remaining.Length; index++) remaining[index].DisplayOrder = -index - 1;
        await SaveAsync(cancellationToken);
        for (var index = 0; index < remaining.Length; index++)
        {
            remaining[index].DisplayOrder = index;
            remaining[index].IsPrimary = image.IsPrimary && index == 0 ? true : remaining[index].IsPrimary;
        }
        if (remaining.Length > 0 && !remaining.Any(x => x.IsPrimary)) remaining[0].IsPrimary = true;
        await SaveAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        try { await storage.DeleteAsync(storageKey, CancellationToken.None); }
        catch (Exception cleanupError) { logger.LogError(cleanupError, "Failed to clean up deleted product image."); }
    }

    public async Task<ProductImageResponseDto> SetPrimaryAsync(Guid userId, Guid productId, Guid imageId, CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellationToken);
        var product = await dbContext.Products.Include(x => x.Images).SingleOrDefaultAsync(x => x.Id == productId && x.SellerUserId == userId && !x.IsDeleted, cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");
        var image = product.Images.SingleOrDefault(x => x.Id == imageId)
            ?? throw new ResourceNotFoundException("La imagen no existe.");
        if (!image.IsPrimary)
        {
            foreach (var current in product.Images.Where(x => x.IsPrimary)) current.IsPrimary = false;
            try { await SaveAsync(cancellationToken); }
            catch (DbUpdateConcurrencyException) { throw new ConflictException("La imagen fue modificada por otro proceso."); }
            image.IsPrimary = true;
            await SaveAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        return ToDto(image);
    }

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        try { await dbContext.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateConcurrencyException) { throw new ConflictException("La imagen fue modificada por otro proceso."); }
        catch (DbUpdateException exception) when (IsKnownImageConflict(exception)) { throw new ConflictException("Las imágenes del producto fueron modificadas simultáneamente."); }
    }

    private static bool IsKnownImageConflict(DbUpdateException exception)
        => exception.InnerException?.Message.Contains("IX_ProductImages_ProductId", StringComparison.OrdinalIgnoreCase) == true;

    private static ProductImageResponseDto ToDto(ProductImage image) => new(image.Id, image.Url, image.ThumbnailUrl, image.DisplayOrder, image.IsPrimary);
}