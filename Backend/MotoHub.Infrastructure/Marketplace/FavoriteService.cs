using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class FavoriteService(MotoHubDbContext dbContext) : IFavoriteService
{
    public async Task<IReadOnlyCollection<ProductResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken)
    {
        var favorites = await dbContext.ProductFavorites
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.Product.Status == ProductStatus.Active && x.Product.Category.IsActive)
            .OrderByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.ProductId)
            .Include(x => x.Product)
            .ThenInclude(x => x.Images)
            .ToListAsync(cancellationToken);
        return favorites.Select(x => ToDto(x.Product)).ToArray();
    }

    public async Task AddAsync(Guid userId, Guid productId, CancellationToken cancellationToken)
    {
        var visible = await dbContext.Products.AnyAsync(
            x => x.Id == productId && x.Status == ProductStatus.Active && x.Category.IsActive,
            cancellationToken);
        if (!visible) throw new ResourceNotFoundException("El producto no existe.");

        if (await dbContext.ProductFavorites.AnyAsync(
                x => x.UserId == userId && x.ProductId == productId,
                cancellationToken)) return;

        var favorite = new ProductFavorite { UserId = userId, ProductId = productId };
        dbContext.ProductFavorites.Add(favorite);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (MarketplaceConflictClassifier.IsProductFavoriteUniqueConflict(exception))
        {
            // The unique key makes a concurrent duplicate add idempotent.
            dbContext.Entry(favorite).State = EntityState.Detached;
        }
    }

    public async Task RemoveAsync(Guid userId, Guid productId, CancellationToken cancellationToken)
    {
        var favorite = await dbContext.ProductFavorites.SingleOrDefaultAsync(
            x => x.UserId == userId && x.ProductId == productId,
            cancellationToken);
        if (favorite is null) return;
        dbContext.ProductFavorites.Remove(favorite);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static ProductResponseDto ToDto(Product product) => new(
        product.Id, product.CategoryId, product.Name, product.Description, product.Price, product.Currency, product.StockQuantity,
        product.Condition, product.Status, product.Location, product.PublishedAt, product.CreatedAt, Convert.ToBase64String(product.RowVersion),
        product.Images.OrderBy(image => image.DisplayOrder).ThenBy(image => image.Id)
            .Select(image => new ProductImageResponseDto(image.Id, image.Url, image.ThumbnailUrl, image.DisplayOrder, image.IsPrimary))
            .ToArray());
}
