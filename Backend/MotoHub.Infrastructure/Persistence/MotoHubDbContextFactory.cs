using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;
using Microsoft.Extensions.Configuration;

namespace MotoHub.Infrastructure.Persistence;

public sealed class MotoHubDbContextFactory : IDesignTimeDbContextFactory<MotoHubDbContext>
{
    public MotoHubDbContext CreateDbContext(string[] args)
    {
        var apiPath = FindApiPath();
        var configuration = new ConfigurationBuilder()
            .SetBasePath(apiPath)
            .AddJsonFile("appsettings.json", optional: false)
            .AddJsonFile("appsettings.Development.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var connectionString = configuration.GetConnectionString("MotoHubDatabase")
            ?? throw new InvalidOperationException("Connection string 'MotoHubDatabase' is not configured.");

        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName))
            .Options;

        return new MotoHubDbContext(options);
    }

    private static string FindApiPath()
    {
        var candidates = new[]
        {
            Path.Combine(Directory.GetCurrentDirectory(), "Backend", "MotoHub.Api"),
            Path.Combine(Directory.GetCurrentDirectory(), "..", "MotoHub.Api"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "MotoHub.Api")
        };

        var apiPath = candidates
            .Select(Path.GetFullPath)
            .FirstOrDefault(path => File.Exists(Path.Combine(path, "appsettings.json")));

        return apiPath ?? throw new DirectoryNotFoundException("MotoHub.Api appsettings.json could not be located.");
    }
}