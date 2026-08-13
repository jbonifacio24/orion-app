using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class MotoHubModelTests
{
    [Fact]
    public void Soft_deletable_entities_have_query_filters()
    {
        using var context = CreateContext();

        var user = context.Model.FindEntityType(typeof(User));
        var motorcycle = context.Model.FindEntityType(typeof(Motorcycle));
        var product = context.Model.FindEntityType(typeof(Product));

        Assert.NotNull(user?.GetQueryFilter());
        Assert.NotNull(motorcycle?.GetQueryFilter());
        Assert.NotNull(product?.GetQueryFilter());
    }

    [Fact]
    public void Motorcycle_model_has_row_version_and_integrity_indexes()
    {
        using var context = CreateContext();
        var entity = context.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(Motorcycle));

        Assert.NotNull(entity);
        Assert.True(entity!.FindProperty(nameof(Entity.RowVersion))!.IsConcurrencyToken);
        Assert.True(entity.FindProperty(nameof(Entity.RowVersion))!.ValueGenerated == ValueGenerated.OnAddOrUpdate);
        Assert.Contains(entity.GetIndexes(), index => index.IsUnique && index.GetFilter() == "[Vin] IS NOT NULL AND [IsDeleted] = 0");
        Assert.Contains(entity.GetCheckConstraints(), constraint => constraint.Name == "CK_Motorcycles_Year");
    }

    [Fact]
    public void Review_model_enforces_rating_range()
    {
        using var context = CreateContext();
        var entity = context.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(ProductReview));

        Assert.NotNull(entity);
        Assert.Contains(entity!.GetCheckConstraints(), constraint => constraint.Name == "CK_ProductReviews_Rating");
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}
