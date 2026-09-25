using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Motorcycles;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Profile;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Administration;
using MotoHub.Infrastructure.Security;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Marketplace;
using MotoHub.Infrastructure.Storage;
using MotoHub.Application.Storage;
using MotoHub.Application.Workshops;
using MotoHub.Infrastructure.Workshops;
using MotoHub.Application.TheftReports;
using MotoHub.Infrastructure.TheftReports;
using MotoHub.Application.Notifications;
using MotoHub.Infrastructure.Notifications;
using MotoHub.Application.Chat;
using MotoHub.Infrastructure.Chat;
using MotoHub.Application.Community;
using MotoHub.Infrastructure.Community;
using MotoHub.Application.News;
using MotoHub.Infrastructure.News;
using MotoHub.Application.Moderation;
using MotoHub.Infrastructure.Moderation;

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
        services.Configure<AdminBootstrapOptions>(configuration.GetSection("AdminBootstrap"));
        services.Configure<EmailOptions>(configuration.GetSection("Email"));
        services.Configure<ProductImageStorageOptions>(configuration.GetSection("ProductImages"));
        services.AddScoped<JwtTokenService>();
        services.AddScoped<IAuthenticationService, AuthenticationService>();
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<AuditPayloadSanitizer>();
        services.AddScoped<IAdminOperationalAccessService, AdminOperationalAccessService>();
        services.AddScoped<IAdminUserService, AdminUserService>();
        services.AddScoped<IAdminAuditQueryService, AdminAuditQueryService>();
        services.AddScoped<DevelopmentUserSeeder>();
        services.AddScoped<AdminBootstrapper>();
        services.AddHttpContextAccessor();
        services.AddScoped<IProfileService, Profile.ProfileService>();
        services.AddScoped<IMotorcycleService, Motorcycles.MotorcycleService>();
        services.AddScoped<IProductService, ProductService>();
        services.AddScoped<ICategoryService, CategoryService>();
        services.AddScoped<IFavoriteService, FavoriteService>();
        services.AddScoped<IProductImageService, ProductImageService>();
        services.AddScoped<IWorkshopService, WorkshopService>();
        services.AddScoped<ITheftReportService, TheftReportService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<IChatService, ChatService>();
        services.AddScoped<ICommunityService, CommunityService>();
        services.AddScoped<INewsService, NewsService>();
        services.AddScoped<IModerationReportService, ModerationReportService>();
        services.AddSingleton<ImageFileValidator>();
        services.AddSingleton<IProductImageStorage, LocalProductImageStorage>();
        services.AddScoped<ProductCategorySeeder>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();
        services.AddSingleton<IPushTokenProtector, AesGcmPushTokenProtector>();

        return services;
    }
}