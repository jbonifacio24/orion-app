using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MotoHub.Domain;
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

    [Fact]
    public async Task Anonymous_status_request_returns_401()
    {
        var response = await factory.CreateClient().PatchAsJsonAsync(
            $"/api/admin/users/{Guid.NewGuid()}/status",
            new { isActive = false, concurrencyToken = "AQ==" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Non_admin_session_revocation_request_returns_403()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.PostAsync($"/api/admin/users/{Guid.NewGuid()}/revoke-sessions", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_can_change_status_and_revoke_sessions()
    {
        var seeded = await SeedAdminUsersAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var statusResponse = await client.PatchAsJsonAsync(
            $"/api/admin/users/{seeded.TargetId}/status",
            new { isActive = false, concurrencyToken = seeded.TargetConcurrencyToken });
        var revokeResponse = await client.PostAsync(
            $"/api/admin/users/{seeded.TargetId}/revoke-sessions",
            null);

        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);
        Assert.Equal(HttpStatusCode.OK, revokeResponse.StatusCode);
        Assert.Contains("revokedCount", await revokeResponse.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }

    private async Task<ApiAdminSeed> SeedAdminUsersAsync()
    {
        var actorId = Guid.NewGuid();
        var targetId = Guid.NewGuid();
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var adminRole = await context.Set<MotoHubIdentityRole>()
            .FirstAsync(role => role.NormalizedName == "ADMIN");
        context.Set<MotoHubIdentityUser>().AddRange(
            IdentityUser(actorId, $"api-admin-{actorId:N}", $"api-admin-{actorId:N}@example.com"),
            IdentityUser(targetId, $"api-target-{targetId:N}", $"api-target-{targetId:N}@example.com"));
        context.Set<IdentityUserRole<Guid>>().Add(new IdentityUserRole<Guid>
        {
            UserId = actorId,
            RoleId = adminRole.Id
        });
        context.Users.AddRange(
            DomainUser(actorId, $"api-admin-{actorId:N}", $"api-admin-{actorId:N}@example.com", [1, 2, 3]),
            DomainUser(targetId, $"api-target-{targetId:N}", $"api-target-{targetId:N}@example.com", [4, 5, 6]));
        await context.SaveChangesAsync();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(user => user.Id == targetId);
        return new ApiAdminSeed(actorId, targetId, Convert.ToBase64String(target.RowVersion));
    }

    private static MotoHubIdentityUser IdentityUser(Guid id, string userName, string email)
        => new()
        {
            Id = id,
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = true
        };

    private static User DomainUser(Guid id, string userName, string email, byte[] rowVersion)
        => new(id)
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            IsActive = true,
            EmailConfirmed = true,
            RowVersion = rowVersion
        };

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

    private sealed record ApiAdminSeed(Guid ActorId, Guid TargetId, string TargetConcurrencyToken);
}
