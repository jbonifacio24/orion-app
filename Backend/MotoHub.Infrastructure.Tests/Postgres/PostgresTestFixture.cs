using System.Net;
using Microsoft.EntityFrameworkCore;
using MotoHub.Infrastructure.Persistence;
using Npgsql;
using Xunit;

namespace MotoHub.Infrastructure.Tests.Postgres;

public sealed class PostgresTestFixture : IAsyncLifetime
{
    private const string ConnectionVariable = "MOTOHUB_TEST_POSTGRES";
    private readonly string databaseName = $"MotoHub_Test_{Guid.NewGuid():N}";
    private NpgsqlConnectionStringBuilder? baseConnection;
    private bool databaseCreated;

    public string DatabaseName => databaseName;
    public string ConnectionString { get; private set; } = string.Empty;

    public async Task InitializeAsync()
    {
        var configuredConnection = Environment.GetEnvironmentVariable(ConnectionVariable);
        if (string.IsNullOrWhiteSpace(configuredConnection))
        {
            throw new InvalidOperationException(
                $"{ConnectionVariable} is required for PostgreSQL integration tests. " +
                "It must target the local postgres maintenance database, never an application database.");
        }

        baseConnection = CreateSafeBaseConnection(configuredConnection);
        ConnectionString = WithDatabase(baseConnection, databaseName).ConnectionString;

        try
        {
            await CreateDatabaseAsync();
            databaseCreated = true;
            await using var context = CreateContext();
            await context.Database.MigrateAsync();

            var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
            if (pendingMigrations.Any())
            {
                throw new InvalidOperationException(
                    $"PostgreSQL test database '{databaseName}' has pending migrations: " +
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
            throw new InvalidOperationException("The PostgreSQL test fixture has not been initialized.");
        }

        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseNpgsql(ConnectionString, postgres =>
                postgres.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName))
            .Options;
        return new MotoHubDbContext(options);
    }

    public async Task DisposeAsync() => await CleanupAsync();

    private async Task CreateDatabaseAsync()
    {
        await using var connection = new NpgsqlConnection(baseConnection!.ConnectionString);
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"CREATE DATABASE {QuoteIdentifier(databaseName)};";
        await command.ExecuteNonQueryAsync();
    }

    private async Task CleanupAsync()
    {
        if (!databaseCreated || baseConnection is null || !IsGeneratedDatabaseName(databaseName))
        {
            return;
        }

        NpgsqlConnection.ClearAllPools();
        try
        {
            await using var connection = new NpgsqlConnection(baseConnection.ConnectionString);
            await connection.OpenAsync();
            await using var command = connection.CreateCommand();
            command.CommandText = $"DROP DATABASE IF EXISTS {QuoteIdentifier(databaseName)} WITH (FORCE);";
            await command.ExecuteNonQueryAsync();
        }
        finally
        {
            NpgsqlConnection.ClearAllPools();
            databaseCreated = false;
        }
    }

    private static NpgsqlConnectionStringBuilder CreateSafeBaseConnection(string value)
    {
        NpgsqlConnectionStringBuilder connection;
        try
        {
            connection = new NpgsqlConnectionStringBuilder(value);
        }
        catch (ArgumentException exception)
        {
            throw new InvalidOperationException($"{ConnectionVariable} is not a valid PostgreSQL connection string.", exception);
        }

        var isLoopback = string.Equals(connection.Host, "localhost", StringComparison.OrdinalIgnoreCase) ||
            IPAddress.TryParse(connection.Host, out var address) && IPAddress.IsLoopback(address);
        if (!isLoopback)
        {
            throw new InvalidOperationException($"{ConnectionVariable} must target localhost or a loopback address.");
        }

        if (!string.Equals(connection.Database, "postgres", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"{ConnectionVariable} must use the postgres maintenance database.");
        }

        if (string.IsNullOrWhiteSpace(connection.Username))
        {
            throw new InvalidOperationException($"{ConnectionVariable} must specify a PostgreSQL username.");
        }

        connection.Pooling = false;
        return connection;
    }

    private static NpgsqlConnectionStringBuilder WithDatabase(NpgsqlConnectionStringBuilder source, string database)
        => new(source.ConnectionString) { Database = database };

    private static bool IsGeneratedDatabaseName(string name)
        => name.StartsWith("MotoHub_Test_", StringComparison.Ordinal) &&
           Guid.TryParseExact(name["MotoHub_Test_".Length..], "N", out _);

    private static string QuoteIdentifier(string identifier) => $"\"{identifier.Replace("\"", "\"\"", StringComparison.Ordinal)}\"";
}