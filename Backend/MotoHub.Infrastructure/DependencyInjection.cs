using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Security;

namespace MotoHub.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("MotoHubDatabase")
            ?? throw new InvalidOperationException("Connection string 'MotoHubDatabase' is not configured.");

        services.AddDbContext<MotoHubDbContext>(options => options.UseSqlServer(connectionString, sql =>
            sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName)));

        services.Configure<PushTokenEncryptionOptions>(configuration.GetSection("Security"));
        services.AddSingleton<IPushTokenProtector, AesGcmPushTokenProtector>();

        return services;
    }
}