using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using MotoHub.Infrastructure.Persistence;

using Xunit;

namespace MotoHub.Infrastructure.Tests.SqlServer;

public sealed class SqlServerTestFixture : IAsyncLifetime
{
    private const string ConnectionVariable = "MOTOHUB_TEST_SQLSERVER";
    private readonly string databaseName = $"MotoHub_Test_{Guid.NewGuid():N}";
    private SqlConnectionStringBuilder baseConnection = null!;

    public string DatabaseName => databaseName;
    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        var configuredConnection = Environment.GetEnvironmentVariable(ConnectionVariable);
        if (string.IsNullOrWhiteSpace(configuredConnection))
        {
            throw new InvalidOperationException(
                $"{ConnectionVariable} is required for SQL Server tests. " +
                "It must point to a LocalDB test instance and must never point to production.");
        }

        baseConnection = CreateSafeBaseConnection(configuredConnection);
        ConnectionString = WithDatabase(baseConnection, databaseName).ConnectionString;

        try
        {
            await CreateDatabaseAsync();
            await using var context = CreateContext();
            await context.Database.MigrateAsync();

            var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
            if (pendingMigrations.Any())
            {
                throw new InvalidOperationException(
                    $"SQL Server test database '{databaseName}' has pending migrations: " +
                    string.Join(", ", pendingMigrations));
            }
        }
        catch
        {
            await CleanupAsync();
            throw;
        }
    }

    public MotoHubDbContext CreateContext()
    {
        if (string.IsNullOrWhiteSpace(ConnectionString))
        {
            throw new InvalidOperationException("The SQL Server test fixture has not been initialized.");
        }

        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseSqlServer(ConnectionString, sql =>
                sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName))
            .Options;
        return new MotoHubDbContext(options);
    }

    public async Task DisposeAsync() => await CleanupAsync();

    private async Task CreateDatabaseAsync()
    {
        await using var connection = new SqlConnection(WithDatabase(baseConnection, "master").ConnectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"CREATE DATABASE {QuoteIdentifier(databaseName)};";
        await command.ExecuteNonQueryAsync();
    }

    private async Task CleanupAsync()
    {
        if (baseConnection is null || !IsGeneratedDatabaseName(databaseName))
        {
            return;
        }

        SqlConnection.ClearAllPools();
        try
        {
            await using var connection = new SqlConnection(WithDatabase(baseConnection, "master").ConnectionString);
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = $"""
                IF DB_ID(N'{databaseName.Replace("'", "''")}') IS NOT NULL
                BEGIN
                    ALTER DATABASE {QuoteIdentifier(databaseName)} SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                    DROP DATABASE {QuoteIdentifier(databaseName)};
                END;
                """;
            await command.ExecuteNonQueryAsync();

            command.CommandText = $"SELECT DB_ID(N'{databaseName.Replace("'", "''")}');";
            if (await command.ExecuteScalarAsync() is not null and not DBNull)
            {
                throw new InvalidOperationException($"SQL Server test database '{databaseName}' was not removed.");
            }
        }
        finally
        {
            SqlConnection.ClearAllPools();
        }
    }

    private static SqlConnectionStringBuilder CreateSafeBaseConnection(string value)
    {
        SqlConnectionStringBuilder connection;
        try
        {
            connection = new SqlConnectionStringBuilder(value);
        }
        catch (ArgumentException exception)
        {
            throw new InvalidOperationException(
                $"{ConnectionVariable} is not a valid SQL Server connection string.", exception);
        }

        if (!string.Equals(
            connection.DataSource,
            @"(localdb)\MSSQLLocalDB",
            StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"{ConnectionVariable} must target SQL Server LocalDB. " +
                "Development and production SQL Server instances are not allowed.");
        }

            if (!connection.IntegratedSecurity)
            {
                throw new InvalidOperationException(
                $"{ConnectionVariable} must use Integrated Security for the LocalDB test instance.");
            }

        if (!string.IsNullOrWhiteSpace(connection.InitialCatalog) &&
            !string.Equals(connection.InitialCatalog, "master", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                $"{ConnectionVariable} must not specify an application database. " +
                "The fixture generates its own database name.");
        }

        connection.InitialCatalog = "master";
        return connection;
    }

    private static SqlConnectionStringBuilder WithDatabase(SqlConnectionStringBuilder source, string database)
    {
        var connection = new SqlConnectionStringBuilder(source.ConnectionString)
        {
            InitialCatalog = database
        };
        return connection;
    }

    private static bool IsGeneratedDatabaseName(string name)
        => name.StartsWith("MotoHub_Test_", StringComparison.Ordinal) &&
           Guid.TryParseExact(name["MotoHub_Test_".Length..], "N", out _);

    private static string QuoteIdentifier(string identifier) => $"[{identifier.Replace("]", "]]", StringComparison.Ordinal)}]";
}