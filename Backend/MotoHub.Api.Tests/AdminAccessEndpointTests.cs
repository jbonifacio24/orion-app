using System.Net;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Domain;
using Xunit;

namespace MotoHub.Api.Tests;

public sealed class AdminAccessEndpointTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory factory;

    public AdminAccessEndpointTests(ApiFactory factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task Anonymous_request_returns_401()
    {
        var client = factory.CreateClient();

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Authenticated_non_admin_request_returns_403()
    {
        var userId = await SeedOperationalUserAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User", userId));

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_request_returns_success()
    {
        var adminId = Guid.NewGuid();
        await SeedOperationalAdminAsync(adminId);
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("Admin", adminId));

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("authorized", await response.Content.ReadAsStringAsync());
    }

    private async Task SeedOperationalAdminAsync(Guid adminId)
    {
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var adminRole = await context.Set<MotoHubIdentityRole>()
            .SingleAsync(role => role.NormalizedName == "ADMIN");
        context.Set<MotoHubIdentityUser>().Add(new MotoHubIdentityUser
        {
            Id = adminId,
            UserName = $"api-admin-{adminId:N}",
            NormalizedUserName = $"API-ADMIN-{adminId:N}",
            Email = $"api-admin-{adminId:N}@example.com",
            NormalizedEmail = $"API-ADMIN-{adminId:N}@EXAMPLE.COM",
            EmailConfirmed = true
        });
        context.Users.Add(new User(adminId)
        {
            UserName = $"api-admin-{adminId:N}",
            NormalizedUserName = $"API-ADMIN-{adminId:N}",
            Email = $"api-admin-{adminId:N}@example.com",
            NormalizedEmail = $"API-ADMIN-{adminId:N}@EXAMPLE.COM",
            IsActive = true,
            EmailConfirmed = true
        });
        context.Set<IdentityUserRole<Guid>>().Add(new IdentityUserRole<Guid>
        {
            UserId = adminId,
            RoleId = adminRole.Id
        });
        await context.SaveChangesAsync();
    }

    private async Task<Guid> SeedOperationalUserAsync()
    {
        var userId = Guid.NewGuid();
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        context.Set<MotoHubIdentityUser>().Add(new MotoHubIdentityUser
        {
            Id = userId,
            UserName = $"api-user-{userId:N}",
            NormalizedUserName = $"API-USER-{userId:N}",
            Email = $"api-user-{userId:N}@example.com",
            NormalizedEmail = $"API-USER-{userId:N}@EXAMPLE.COM",
            EmailConfirmed = true
        });
        context.Users.Add(new User(userId)
        {
            UserName = $"api-user-{userId:N}",
            NormalizedUserName = $"API-USER-{userId:N}",
            Email = $"api-user-{userId:N}@example.com",
            NormalizedEmail = $"API-USER-{userId:N}@EXAMPLE.COM",
            IsActive = true,
            EmailConfirmed = true
        });
        await context.SaveChangesAsync();
        return userId;
    }

    private static string CreateToken(string role, Guid? userId = null)
    {
        var tokenService = new JwtTokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            AccessTokenMinutes = 10
        }));
        return tokenService.Create(
            new MotoHubIdentityUser
            {
                Id = userId ?? Guid.NewGuid(),
                UserName = "api-test-user",
                Email = "api-test@example.com"
            },
            [role]).Token;
    }
}

public class ApiFactory : WebApplicationFactory<Program>
{
    public const string Issuer = "MotoHub.Api.Tests";
    public const string Audience = "MotoHub.Api.Tests.Client";
    public const string SigningKey = "01234567890123456789012345678901";
    private readonly string databaseName = $"api-tests-{Guid.NewGuid():N}";
    private const string DatabaseConnectionString = "Server=(localdb)\\MSSQLLocalDB;Database=MotoHubApiTests;Trusted_Connection=True;TrustServerCertificate=True";

    protected virtual int AuthPermitLimit => 1000;

    public ApiFactory()
    {
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:MotoHubDatabase", DatabaseConnectionString);
        builder.UseSetting("Jwt:Issuer", Issuer);
        builder.UseSetting("Jwt:Audience", Audience);
        builder.UseSetting("Jwt:SigningKey", SigningKey);
        builder.UseSetting("Jwt:AccessTokenMinutes", "10");
        builder.UseSetting("Jwt:RefreshTokenDays", "14");
        builder.UseSetting("Auth:RequireConfirmedEmail", "false");
        builder.UseSetting("Email:Enabled", "false");
        builder.UseSetting("RateLimiting:AuthPermitLimit", AuthPermitLimit.ToString());
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:MotoHubDatabase"] = DatabaseConnectionString,
                ["Jwt:Issuer"] = Issuer,
                ["Jwt:Audience"] = Audience,
                ["Jwt:SigningKey"] = SigningKey,
                ["Jwt:AccessTokenMinutes"] = "10",
                ["Jwt:RefreshTokenDays"] = "14",
                ["Auth:RequireConfirmedEmail"] = "false",
                ["Email:Enabled"] = "false",
                ["RateLimiting:AuthPermitLimit"] = AuthPermitLimit.ToString()
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<MotoHubDbContext>>();
            services.AddDbContext<MotoHubDbContext>(options => options
                .UseInMemoryDatabase(databaseName)
                .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        });
    }
}
