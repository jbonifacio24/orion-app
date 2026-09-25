using System.Net;
using System.Net.Http.Headers;
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
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_request_returns_success()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("Admin"));

        var response = await client.GetAsync("/api/admin/access");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("authorized", await response.Content.ReadAsStringAsync());
    }

    private static string CreateToken(string role)
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
                Id = Guid.NewGuid(),
                UserName = "api-test-user",
                Email = "api-test@example.com"
            },
            [role]).Token;
    }
}

public sealed class ApiFactory : WebApplicationFactory<Program>
{
    public const string Issuer = "MotoHub.Api.Tests";
    public const string Audience = "MotoHub.Api.Tests.Client";
    public const string SigningKey = "01234567890123456789012345678901";
    private const string DatabaseConnectionString = "Server=(localdb)\\MSSQLLocalDB;Database=MotoHubApiTests;Trusted_Connection=True;TrustServerCertificate=True";

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:MotoHubDatabase", DatabaseConnectionString);
        builder.UseSetting("Jwt:Issuer", Issuer);
        builder.UseSetting("Jwt:Audience", Audience);
        builder.UseSetting("Jwt:SigningKey", SigningKey);
        builder.UseSetting("Jwt:AccessTokenMinutes", "10");
        builder.UseSetting("Jwt:RefreshTokenDays", "14");
        builder.UseSetting("Email:Enabled", "false");
        builder.ConfigureAppConfiguration((_, configuration) => configuration.AddInMemoryCollection(
            new Dictionary<string, string?>
            {
                ["ConnectionStrings:MotoHubDatabase"] = DatabaseConnectionString,
                ["Jwt:Issuer"] = Issuer,
                ["Jwt:Audience"] = Audience,
                ["Jwt:SigningKey"] = SigningKey,
                ["Jwt:AccessTokenMinutes"] = "10",
                ["Jwt:RefreshTokenDays"] = "14",
                ["Email:Enabled"] = "false"
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<MotoHubDbContext>>();
            services.AddDbContext<MotoHubDbContext>(options => options
                .UseInMemoryDatabase("api-tests")
                .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        });
    }
}
