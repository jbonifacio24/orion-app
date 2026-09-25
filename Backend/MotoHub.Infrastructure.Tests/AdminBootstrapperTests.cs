using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class AdminBootstrapperTests
{
    [Fact]
    public async Task Creates_admin_role_without_elevating_any_user_when_configuration_is_absent()
    {
        await using var provider = CreateProvider(null);
        await using var scope = provider.CreateAsyncScope();
        var bootstrapper = scope.ServiceProvider.GetRequiredService<AdminBootstrapper>();

        await bootstrapper.SeedAsync();
        await bootstrapper.SeedAsync();

        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        Assert.Equal(1, await context.Set<MotoHubIdentityRole>().CountAsync(x => x.Name == AdminSecurity.AdminRole));
        Assert.Empty(await context.Set<MotoHubIdentityUser>().ToListAsync());
        Assert.Single(await context.AuditLogs.Where(x => x.Action == "AdminRoleCreated").ToListAsync());
    }

    [Fact]
    public async Task Assigns_admin_role_to_existing_configured_user_without_creating_an_account()
    {
        await using var provider = CreateProvider("admin@example.com");
        await using var scope = provider.CreateAsyncScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>();
        var user = new MotoHubIdentityUser
        {
            Id = Guid.NewGuid(),
            UserName = "existing-admin",
            Email = "admin@example.com",
            EmailConfirmed = true
        };
        var result = await userManager.CreateAsync(user, "StrongPassword1!");
        Assert.True(result.Succeeded, string.Join("; ", result.Errors.Select(error => error.Code + ": " + error.Description)));

        await scope.ServiceProvider.GetRequiredService<AdminBootstrapper>().SeedAsync();

        Assert.True(await userManager.IsInRoleAsync(user, AdminSecurity.AdminRole));
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        Assert.Single(await context.Set<MotoHubIdentityUser>().ToListAsync());
        Assert.Single(await context.AuditLogs.Where(x => x.Action == "AdminRoleAssigned").ToListAsync());
    }

    [Fact]
    public async Task Missing_configured_user_does_not_create_an_account()
    {
        await using var provider = CreateProvider("missing@example.com");
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider.GetRequiredService<AdminBootstrapper>().SeedAsync();

        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        Assert.Empty(await context.Set<MotoHubIdentityUser>().ToListAsync());
        Assert.True(await context.Set<MotoHubIdentityRole>().AnyAsync(x => x.Name == AdminSecurity.AdminRole));
        Assert.DoesNotContain(await context.AuditLogs.ToListAsync(), x => x.Action == "AdminRoleAssigned");
    }

    private static ServiceProvider CreateProvider(string? configuredEmail)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddHttpContextAccessor();
        services.AddDataProtection();
        services.AddDbContext<MotoHubDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<MotoHubIdentityUser>()
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>()
            .AddDefaultTokenProviders();
        services.Configure<AdminBootstrapOptions>(options => options.UserEmail = configuredEmail);
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<AdminBootstrapper>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }
}
