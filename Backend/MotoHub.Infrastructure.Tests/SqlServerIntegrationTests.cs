using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerIntegrationTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Fase2_database_has_expected_schema_and_no_pending_migrations()
    {
        await using var context = fixture.CreateContext();
        Assert.True(await context.Database.CanConnectAsync());
        Assert.Empty(await context.Database.GetPendingMigrationsAsync());
        Assert.Contains(
            "20260813011653_InitialDatabase",
            await context.Database.GetAppliedMigrationsAsync());

        await using var connection = context.Database.GetDbConnection();
        await connection.OpenAsync();

        Assert.Equal(fixture.DatabaseName, connection.Database);
        Assert.Equal(7, await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.tables WHERE name IN ('Users', 'Motorcycles', 'Products', 'Conversations', 'Posts', 'News', 'AuditLogs')"));
        Assert.True(await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.indexes WHERE name IN ('IX_Users_NormalizedEmail', 'IX_Motorcycles_Vin', 'IX_Products_Status_CreatedAt')") >= 3);
        Assert.True(await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.check_constraints WHERE name IN ('CK_Motorcycles_Year', 'CK_Products_Price', 'CK_ProductReviews_Rating')") >= 3);
    }

    private static async Task<int> ScalarCountAsync(DbConnection connection, string sql)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }
}