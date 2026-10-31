using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using MotoHub.Domain;
using MotoHub.Infrastructure.Tests.Postgres;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(PostgresCollection.Name)]
[Trait("Category", "Postgres")]
[Trait("Category", "Integration")]
public sealed class PostgresConcurrencyTokenTests(PostgresTestFixture fixture)
{
    [Fact]
    public async Task Product_concurrency_token_uses_required_bytea()
    {
        await using var context = fixture.CreateContext();
        var property = context.Model.FindEntityType(typeof(Product))!.FindProperty(nameof(Entity.RowVersion));

        Assert.NotNull(property);
        Assert.True(property!.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.Never, property.ValueGenerated);
        Assert.Equal("bytea", property.GetColumnType());
        Assert.False(property.IsNullable);
    }

    [Fact]
    public async Task Product_concurrency_token_is_generated_and_changes_after_update()
    {
        var productId = await CreateProductAsync();
        byte[] initialRowVersion;

        await using (var context = fixture.CreateContext())
        {
            var product = await context.Products.SingleAsync(x => x.Id == productId);
            initialRowVersion = product.RowVersion.ToArray();
            Assert.Equal(16, initialRowVersion.Length);

            product.Name = "Updated product";
            await context.SaveChangesAsync();

            Assert.Equal(16, product.RowVersion.Length);
            Assert.False(initialRowVersion.SequenceEqual(product.RowVersion));
        }
    }

    [Fact]
    public async Task Product_stale_concurrency_token_update_throws_with_independent_contexts()
    {
        var productId = await CreateProductAsync();
        await using var contextA = fixture.CreateContext();
        await using var contextB = fixture.CreateContext();
        var productA = await contextA.Products.SingleAsync(x => x.Id == productId);
        var productB = await contextB.Products.SingleAsync(x => x.Id == productId);

        productB.Name = "Context B update";
        await contextB.SaveChangesAsync();
        productA.Name = "Context A stale update";

        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => contextA.SaveChangesAsync());
    }

    [Fact]
    public async Task Moderation_report_token_is_not_a_concurrency_token()
    {
        await using var context = fixture.CreateContext();
        var entity = context.Model.FindEntityType(typeof(ModerationReport));
        var property = entity?.FindProperty(nameof(Entity.RowVersion));
        Assert.NotNull(property);
        Assert.False(property!.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.Never, property.ValueGenerated);
        Assert.Equal("bytea", property.GetColumnType());
        Assert.False(property.IsNullable);
    }

    [Fact]
    public async Task Moderation_report_token_is_unchanged_by_updates()
    {
        var reportId = await CreateUserReportAsync();
        byte[] initialRowVersion;

        await using (var context = fixture.CreateContext())
        {
            var report = await context.UserReports.SingleAsync(x => x.Id == reportId);
            initialRowVersion = report.RowVersion.ToArray();
            report.Resolution = "Resolved";
            await context.SaveChangesAsync();
            Assert.Equal(initialRowVersion, report.RowVersion);
        }

        await using var contextA = fixture.CreateContext();
        await using var contextB = fixture.CreateContext();
        var reportA = await contextA.UserReports.SingleAsync(x => x.Id == reportId);
        var reportB = await contextB.UserReports.SingleAsync(x => x.Id == reportId);
        reportB.Resolution = "Context B resolution";
        await contextB.SaveChangesAsync();
        reportA.Resolution = "Context A resolution";

        var exception = await Record.ExceptionAsync(() => contextA.SaveChangesAsync());
        Assert.Null(exception);
        Assert.Equal(initialRowVersion, reportA.RowVersion);
    }

    private async Task<Guid> CreateProductAsync()
    {
        await using var context = fixture.CreateContext();
        var user = new User
        {
            UserName = $"rowversion-{Guid.NewGuid():N}",
            NormalizedUserName = $"ROWVERSION-{Guid.NewGuid():N}",
            Email = $"rowversion-{Guid.NewGuid():N}@example.test",
            NormalizedEmail = $"ROWVERSION-{Guid.NewGuid():N}@EXAMPLE.TEST"
        };
        var category = new ProductCategory
        {
            Name = $"RowVersion {Guid.NewGuid():N}",
            Slug = $"rowversion-{Guid.NewGuid():N}"
        };
        var product = new Product
        {
            Seller = user,
            Category = category,
            Name = "Initial product",
            Description = "RowVersion characterization",
            Condition = ProductCondition.New,
            Status = ProductStatus.Draft
        };

        context.Products.Add(product);
        await context.SaveChangesAsync();
        return product.Id;
    }

    private async Task<Guid> CreateUserReportAsync()
    {
        await using var context = fixture.CreateContext();
        var reporter = NewUser("reporter");
        var reported = NewUser("reported");
        var report = new UserReport
        {
            Reporter = reporter,
            ReportedUser = reported,
            Reason = "Characterization",
            Status = ModerationReportStatus.Pending
        };

        context.UserReports.Add(report);
        await context.SaveChangesAsync();
        return report.Id;
    }

    private static User NewUser(string prefix)
    {
        var suffix = Guid.NewGuid().ToString("N");
        return new User
        {
            UserName = $"{prefix}-{suffix}",
            NormalizedUserName = $"{prefix}-{suffix}".ToUpperInvariant(),
            Email = $"{prefix}-{suffix}@example.test",
            NormalizedEmail = $"{prefix}-{suffix}@EXAMPLE.TEST"
        };
    }

}
