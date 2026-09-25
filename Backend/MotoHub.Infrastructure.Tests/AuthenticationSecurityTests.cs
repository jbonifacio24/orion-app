using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class AuthenticationSecurityTests
{
    [Fact]
    public async Task Active_user_can_login_refresh_and_read_current_user()
    {
        await using var provider = await CreateProviderAsync(isActive: true);
        await using var scope = provider.CreateAsyncScope();
        var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();

        var login = await authentication.LoginAsync(new LoginRequest("security@example.com", "StrongPassword1!"), null, default);
        var refreshed = await authentication.RefreshAsync(new RefreshTokenRequest(login.RefreshToken), null, default);
        var current = await authentication.GetCurrentUserAsync(login.User.Id, default);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();

        Assert.NotEqual(login.AccessToken, refreshed.AccessToken);
        Assert.Equal(login.User.Id, current.Id);
        Assert.DoesNotContain(await context.RefreshTokens.ToListAsync(), token => token.TokenHash == login.RefreshToken);
    }

    [Fact]
    public async Task Inactive_user_cannot_login()
    {
        await using var provider = await CreateProviderAsync(isActive: false);
        await using var scope = provider.CreateAsyncScope();
        var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();

        var exception = await Assert.ThrowsAsync<AuthenticationException>(() =>
            authentication.LoginAsync(new LoginRequest("security@example.com", "StrongPassword1!"), null, default));

        Assert.Equal(401, exception.StatusCode);
    }

    [Fact]
    public async Task Inactive_user_cannot_refresh_and_existing_refresh_sessions_are_revoked()
    {
        await using var provider = await CreateProviderAsync(isActive: true);
        await using var scope = provider.CreateAsyncScope();
        var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();
        var login = await authentication.LoginAsync(new LoginRequest("security@example.com", "StrongPassword1!"), null, default);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var profile = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == login.User.Id);
        profile.IsActive = false;
        await context.SaveChangesAsync();

        var exception = await Assert.ThrowsAsync<AuthenticationException>(() =>
            authentication.RefreshAsync(new RefreshTokenRequest(login.RefreshToken), null, default));

        Assert.Equal(401, exception.StatusCode);
        Assert.All(await context.RefreshTokens.Where(x => x.UserId == login.User.Id).ToListAsync(), token =>
            Assert.NotNull(token.RevokedAt));
    }

    [Fact]
    public async Task Inactive_user_cannot_read_current_user()
    {
        await using var provider = await CreateProviderAsync(isActive: false);
        await using var scope = provider.CreateAsyncScope();
        var authentication = scope.ServiceProvider.GetRequiredService<AuthenticationService>();
        var user = await scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>().FindByEmailAsync("security@example.com");
        Assert.NotNull(user);

        var exception = await Assert.ThrowsAsync<AuthenticationException>(() =>
            authentication.GetCurrentUserAsync(user!.Id, default));

        Assert.Equal(401, exception.StatusCode);
    }

    private static async Task<ServiceProvider> CreateProviderAsync(bool isActive)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddHttpContextAccessor();
        services.AddDataProtection();
        services.AddAuthentication();
        var databaseRoot = new InMemoryDatabaseRoot();
        services.AddDbContext<MotoHubDbContext>(options => options
            .UseInMemoryDatabase("authentication-security-tests", databaseRoot)
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<MotoHubIdentityUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.SignIn.RequireConfirmedEmail = false;
                options.Password.RequiredLength = 12;
                options.Password.RequireDigit = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireLowercase = true;
                options.Lockout.MaxFailedAccessAttempts = 5;
            })
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>()
            .AddSignInManager()
            .AddDefaultTokenProviders();
        services.Configure<JwtOptions>(options =>
        {
            options.Issuer = "MotoHub.Tests";
            options.Audience = "MotoHub.Tests.Client";
            options.SigningKey = "01234567890123456789012345678901";
            options.AccessTokenMinutes = 10;
            options.RefreshTokenDays = 14;
        });
        services.Configure<AuthOptions>(options => options.RequireConfirmedEmail = false);
        services.AddScoped<JwtTokenService>();
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<AuthenticationService>();
        services.AddSingleton<IEmailSender, NoOpEmailSender>();

        var provider = services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
        await using var scope = provider.CreateAsyncScope();
        var user = new MotoHubIdentityUser
        {
            Id = Guid.NewGuid(),
            UserName = "security-user",
            Email = "security@example.com",
            EmailConfirmed = true
        };
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<MotoHubIdentityUser>>();
        var result = await userManager.CreateAsync(user, "StrongPassword1!");
        Assert.True(result.Succeeded, string.Join("; ", result.Errors.Select(error => error.Code + ": " + error.Description)));
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        context.Users.Add(new User(user.Id)
        {
            UserName = user.UserName,
            NormalizedUserName = user.UserName.ToUpperInvariant(),
            Email = user.Email,
            NormalizedEmail = user.Email.ToUpperInvariant(),
            IsActive = isActive,
            EmailConfirmed = true
        });
        await context.SaveChangesAsync();
        return provider;
    }

    private sealed class NoOpEmailSender : IEmailSender
    {
        public Task SendAsync(string recipient, string subject, string body, CancellationToken cancellationToken)
            => Task.CompletedTask;
    }
}
