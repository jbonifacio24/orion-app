using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using MotoHub.Domain;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerRowVersionTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Product_row_version_matches_ef_metadata_and_sql_server_schema()
    {
        await using var context = fixture.CreateContext();
        var property = context.Model.FindEntityType(typeof(Product))!.FindProperty(nameof(Entity.RowVersion));
        var metadata = await ReadColumnMetadataAsync(context.Database.GetDbConnection(), "Products");

        Assert.NotNull(property);
        Assert.True(property!.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.OnAddOrUpdate, property.ValueGenerated);
        Assert.Equal("rowversion", property.GetColumnType());
        Assert.Contains(metadata.TypeName, new[] { "timestamp", "rowversion" }, StringComparer.OrdinalIgnoreCase);
        Assert.Equal(8, metadata.MaxLength);
        Assert.False(metadata.IsNullable);
        Assert.False(metadata.IsRowGuidColumn);
        Assert.Equal(0, metadata.GeneratedAlwaysType);
    }

    [Fact]
    public async Task Product_row_version_is_generated_and_changes_after_update()
    {
        var productId = await CreateProductAsync();
        byte[] initialRowVersion;

        await using (var context = fixture.CreateContext())
        {
            var product = await context.Products.SingleAsync(x => x.Id == productId);
            initialRowVersion = product.RowVersion.ToArray();
            Assert.Equal(8, initialRowVersion.Length);

            product.Name = "Updated product";
            await context.SaveChangesAsync();

            Assert.Equal(8, product.RowVersion.Length);
            Assert.False(initialRowVersion.SequenceEqual(product.RowVersion));
        }
    }

    [Fact]
    public async Task Product_stale_row_version_update_throws_with_independent_contexts()
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
    public async Task Moderation_report_row_version_characterizes_ef_metadata_and_sql_schema()
    {
        await using var context = fixture.CreateContext();
        var entity = context.Model.FindEntityType(typeof(ModerationReport));
        var property = entity?.FindProperty(nameof(Entity.RowVersion));
        var metadata = await ReadColumnMetadataAsync(context.Database.GetDbConnection(), "ModerationReports");

        Assert.NotNull(property);
        Assert.False(property!.IsConcurrencyToken);
        Assert.Equal(ValueGenerated.Never, property.ValueGenerated);
        Assert.Equal("varbinary(max)", property.GetColumnType());
        Assert.Equal("varbinary", metadata.TypeName, ignoreCase: true);
        Assert.Equal(-1, metadata.MaxLength);
        Assert.False(metadata.IsNullable);
        Assert.False(metadata.IsRowGuidColumn);
        Assert.Equal(0, metadata.GeneratedAlwaysType);
    }

    [Fact]
    public async Task Moderation_report_row_version_insert_update_and_stale_update_are_characterized()
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

    private static async Task<SqlColumnMetadata> ReadColumnMetadataAsync(DbConnection connection, string tableName)
    {
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT c.name, t.name, c.max_length, c.is_nullable, c.is_rowguidcol, c.generated_always_type
            FROM sys.columns AS c
            INNER JOIN sys.types AS t ON c.user_type_id = t.user_type_id
            WHERE c.object_id = OBJECT_ID(@tableName) AND c.name = N'RowVersion';
            """;
        AddParameter(command, "@tableName", tableName);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync(), $"RowVersion column was not found in {tableName}.");
        return new SqlColumnMetadata(
            reader.GetString(1),
            reader.GetInt16(2),
            reader.GetBoolean(3),
            reader.GetBoolean(4),
            reader.GetByte(5));
    }

    private static void AddParameter(DbCommand command, string name, string value)
    {
        var parameter = command.CreateParameter();
        parameter.ParameterName = name;
        parameter.Value = value;
        command.Parameters.Add(parameter);
    }

    private sealed record SqlColumnMetadata(
        string TypeName,
        short MaxLength,
        bool IsNullable,
        bool IsRowGuidColumn,
        byte GeneratedAlwaysType);
}
