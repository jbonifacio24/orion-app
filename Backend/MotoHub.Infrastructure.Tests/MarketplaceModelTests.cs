using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Marketplace;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class MarketplaceModelTests
{
    [Fact]
    public void Marketplace_model_has_soft_delete_and_integrity_indexes()
    {
        using var context = CreateContext();
        var product = context.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(Product));
        var favorite = context.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(ProductFavorite));
        var image = context.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(ProductImage));

        Assert.NotNull(product?.GetQueryFilter());
        Assert.NotNull(context.Model.FindEntityType(typeof(ProductCategory))?.GetQueryFilter());
        Assert.Contains(favorite!.GetKeys(), key => key.Properties.Count == 2 && key.Properties[0].Name == nameof(ProductFavorite.UserId) && key.Properties[1].Name == nameof(ProductFavorite.ProductId));
        Assert.Contains(image!.GetIndexes(), index => index.IsUnique && index.GetFilter() == "[IsPrimary] = 1");
        Assert.True(product!.FindProperty(nameof(Entity.RowVersion))!.IsConcurrencyToken);
    }

    [Theory]
    [InlineData(2601, "Violation of unique index IX_ProductFavorites_UserId_ProductId.")]
    [InlineData(2627, "Violation of unique constraint PK_ProductFavorites.")]
    public void Product_favorite_unique_conflicts_are_classified(int errorNumber, string message)
        => Assert.True(MarketplaceConflictClassifier.IsProductFavoriteUniqueConflict(errorNumber, message));

    [Fact]
    public void Unknown_sql_errors_are_not_classified_as_favorite_conflicts()
    {
        Assert.False(MarketplaceConflictClassifier.IsProductFavoriteUniqueConflict(547, "Foreign key ProductFavorites."));
        Assert.False(MarketplaceConflictClassifier.IsProductFavoriteUniqueConflict(2601, "IX_OtherTable_OtherIndex"));
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        return new MotoHubDbContext(options);
    }
}
