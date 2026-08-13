using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class SqlServerIntegrationTests
{
    [Fact]
    [Trait("Category", "Integration")]
    public async Task Fase2_database_has_expected_schema_and_no_pending_migrations()
    {
        var configuration = BuildConfiguration();
        var connectionString = configuration.GetConnectionString("MotoHubDatabase")
            ?? throw new InvalidOperationException("MotoHubDatabase connection string is not configured.");
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseSqlServer(connectionString)
            .Options;

        await using var context = new MotoHubDbContext(options);
        Assert.True(await context.Database.CanConnectAsync());
        Assert.Empty(await context.Database.GetPendingMigrationsAsync());
        Assert.Contains(
            "20260813011653_InitialDatabase",
            await context.Database.GetAppliedMigrationsAsync());

        await using var connection = context.Database.GetDbConnection();
        await connection.OpenAsync();

        Assert.Equal(7, await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.tables WHERE name IN ('Users', 'Motorcycles', 'Products', 'Conversations', 'Posts', 'News', 'AuditLogs')"));
        Assert.True(await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.indexes WHERE name IN ('IX_Users_NormalizedEmail', 'IX_Motorcycles_Vin', 'IX_Products_Status_CreatedAt')") >= 3);
        Assert.True(await ScalarCountAsync(connection, "SELECT COUNT(*) FROM sys.check_constraints WHERE name IN ('CK_Motorcycles_Year', 'CK_Products_Price', 'CK_ProductReviews_Rating')") >= 3);
    }

    private static IConfiguration BuildConfiguration()
    {
        var apiPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "MotoHub.Api"));
        return new ConfigurationBuilder()
            .SetBasePath(apiPath)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Development.json", optional: false)
            .AddEnvironmentVariables()
            .Build();
    }

    private static async Task<int> ScalarCountAsync(System.Data.Common.DbConnection connection, string sql)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        return Convert.ToInt32(await command.ExecuteScalarAsync());
    }
}