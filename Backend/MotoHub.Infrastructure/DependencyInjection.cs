using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Security;
using MotoHub.Infrastructure.Authentication;

namespace MotoHub.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("MotoHubDatabase")
            ?? throw new InvalidOperationException("Connection string 'MotoHubDatabase' is not configured.");

        services.AddDbContext<MotoHubDbContext>(options => options.UseSqlServer(connectionString, sql =>
            sql.MigrationsAssembly(typeof(MotoHubDbContext).Assembly.FullName)));

        services.AddIdentityCore<MotoHubIdentityUser>(options =>
        {
            options.User.RequireUniqueEmail = true;
            options.SignIn.RequireConfirmedEmail = false;
            options.Password.RequiredLength = 12;
            options.Password.RequireDigit = true;
            options.Password.RequireUppercase = true;
            options.Password.RequireLowercase = true;
            options.Password.RequireNonAlphanumeric = false;
            options.Lockout.MaxFailedAccessAttempts = 5;
            options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
        })
        .AddRoles<MotoHubIdentityRole>()
        .AddEntityFrameworkStores<MotoHubDbContext>()
        .AddSignInManager()
        .AddDefaultTokenProviders();

        services.Configure<PushTokenEncryptionOptions>(configuration.GetSection("Security"));
        services.Configure<JwtOptions>(configuration.GetSection("Jwt"));
        services.Configure<AuthOptions>(configuration.GetSection("Auth"));
        services.Configure<EmailOptions>(configuration.GetSection("Email"));
        services.AddScoped<JwtTokenService>();
        services.AddScoped<IAuthenticationService, AuthenticationService>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();
        services.AddSingleton<IPushTokenProtector, AesGcmPushTokenProtector>();

        return services;
    }
}