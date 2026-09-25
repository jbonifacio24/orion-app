using System.Net;
using System.Net.Http.Headers;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Api.Tests;

public sealed class AdminUsersEndpointTests : IClassFixture<ApiFactory>
{
    private readonly ApiFactory factory;

    public AdminUsersEndpointTests(ApiFactory factory)
    {
        this.factory = factory;
    }

    [Fact]
    public async Task Anonymous_list_request_returns_401()
    {
        var response = await factory.CreateClient().GetAsync("/api/admin/users");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Non_admin_list_request_returns_403()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.GetAsync("/api/admin/users");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_list_request_returns_paged_response()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("Admin"));

        var response = await client.GetAsync("/api/admin/users?page=1&pageSize=20");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("totalCount", body, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("items", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Admin_detail_request_for_missing_user_returns_404()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("Admin"));

        var response = await client.GetAsync($"/api/admin/users/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Admin_detail_request_for_existing_user_returns_200()
    {
        var userId = Guid.NewGuid();
        using (var scope = factory.Services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            dbContext.Set<MotoHubIdentityUser>().Add(new MotoHubIdentityUser
            {
                Id = userId,
                UserName = "detail-test-user",
                NormalizedUserName = "DETAIL-TEST-USER",
                Email = "detail-test@example.com",
                NormalizedEmail = "DETAIL-TEST@EXAMPLE.COM"
            });
            await dbContext.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("Admin"));
        var response = await client.GetAsync($"/api/admin/users/{userId}");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("detail-test-user", body, StringComparison.Ordinal);
        Assert.Contains("profileMissing", body, StringComparison.OrdinalIgnoreCase);
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
