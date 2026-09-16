using Microsoft.EntityFrameworkCore;
using MotoHub.Infrastructure.Marketplace;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class MarketplaceSeedTests
{
    [Fact]
    public async Task Category_seed_inserts_missing_categories_idempotently_without_overwriting_existing_values()
    {
        await using var context = CreateContext();
        context.ProductCategories.Add(new MotoHub.Domain.ProductCategory { Name = "Custom name", Slug = "repuestos", IsActive = false, DisplayOrder = 999 });
        await context.SaveChangesAsync();
        var seeder = new ProductCategorySeeder(context);

        await seeder.SeedAsync(default);
        await seeder.SeedAsync(default);

        var categories = await context.ProductCategories.IgnoreQueryFilters().ToListAsync();
        Assert.Equal(8, categories.Count);
        var existing = categories.Single(x => x.Slug == "repuestos");
        Assert.Equal("Custom name", existing.Name);
        Assert.False(existing.IsActive);
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        return new MotoHubDbContext(options);
    }
}
