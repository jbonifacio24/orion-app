using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Marketplace;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerProductConcurrencyTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Product_service_rejects_stale_update_and_preserves_winning_value()
    {
        var (ownerId, categoryId, productId) = await CreateProductAsync();

        await using var actorAContext = fixture.CreateContext();
        await using var actorBContext = fixture.CreateContext();
        var actorAProduct = await actorAContext.Products.SingleAsync(x => x.Id == productId);
        var actorBProduct = await actorBContext.Products.SingleAsync(x => x.Id == productId);
        var initialRowVersion = actorAProduct.RowVersion.ToArray();

        Assert.Equal(initialRowVersion, actorBProduct.RowVersion);

        var actorAResult = await new ProductService(actorAContext).UpdateAsync(
            ownerId,
            productId,
            UpdateRequest(categoryId, "Actor A", initialRowVersion),
            default);
        var winningRowVersion = Convert.FromBase64String(actorAResult.RowVersion);

        Assert.NotEqual(initialRowVersion, winningRowVersion);

        await Assert.ThrowsAsync<ConflictException>(() => new ProductService(actorBContext).UpdateAsync(
            ownerId,
            productId,
            UpdateRequest(categoryId, "Actor B", initialRowVersion),
            default));

        await using var verificationContext = fixture.CreateContext();
        var persistedProduct = await verificationContext.Products.SingleAsync(x => x.Id == productId);

        Assert.Equal("Actor A", persistedProduct.Name);
        Assert.NotEqual(initialRowVersion, persistedProduct.RowVersion);
        Assert.Equal(winningRowVersion, persistedProduct.RowVersion);
    }

    private async Task<(Guid OwnerId, Guid CategoryId, Guid ProductId)> CreateProductAsync()
    {
        await using var context = fixture.CreateContext();
        var suffix = Guid.NewGuid().ToString("N");
        var owner = new User
        {
            UserName = $"concurrency-owner-{suffix}",
            NormalizedUserName = $"CONCURRENCY-OWNER-{suffix}",
            Email = $"concurrency-owner-{suffix}@example.test",
            NormalizedEmail = $"CONCURRENCY-OWNER-{suffix}@EXAMPLE.TEST"
        };
        var category = new ProductCategory
        {
            Name = $"Concurrency category {suffix}",
            Slug = $"concurrency-category-{suffix}",
            IsActive = true,
            DisplayOrder = 1
        };
        var product = new Product
        {
            Seller = owner,
            Category = category,
            Name = "Initial product",
            Description = "Product concurrency characterization",
            Condition = ProductCondition.New,
            Status = ProductStatus.Active
        };

        context.Products.Add(product);
        await context.SaveChangesAsync();
        return (owner.Id, category.Id, product.Id);
    }

    private static UpdateProductRequestDto UpdateRequest(Guid categoryId, string name, byte[] rowVersion)
        => new(
            categoryId,
            name,
            "Product concurrency characterization",
            null,
            null,
            null,
            ProductCondition.New,
            null,
            Convert.ToBase64String(rowVersion));
}