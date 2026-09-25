using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
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

    [Fact]
    public async Task Anonymous_roles_request_returns_401()
    {
        var response = await factory.CreateClient().PutAsJsonAsync(
            $"/api/admin/users/{Guid.NewGuid()}/roles",
            new { roles = new[] { "Admin" }, concurrencyToken = "AQ==" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Non_admin_roles_request_returns_403()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.PutAsJsonAsync(
            $"/api/admin/users/{Guid.NewGuid()}/roles",
            new { roles = new[] { "Admin" }, concurrencyToken = "AQ==" });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_can_replace_roles()
    {
        var seeded = await SeedAdminUsersAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.PutAsJsonAsync(
            $"/api/admin/users/{seeded.TargetId}/roles",
            new { roles = new[] { seeded.RoleName }, concurrencyToken = seeded.TargetConcurrencyToken });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("roles", await response.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Admin_roles_request_with_stale_token_returns_409()
    {
        var seeded = await SeedAdminUsersAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.PutAsJsonAsync(
            $"/api/admin/users/{seeded.TargetId}/roles",
            new { roles = new[] { seeded.RoleName }, concurrencyToken = "AQ==" });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Anonymous_audit_list_request_returns_401()
    {
        var response = await factory.CreateClient().GetAsync("/api/admin/audit-logs");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Non_admin_audit_list_request_returns_403()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.GetAsync("/api/admin/audit-logs");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_can_list_audit_logs_without_sensitive_list_fields()
    {
        var seeded = await SeedAdminUsersAsync();
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            context.AuditLogs.Add(new AuditLog
            {
                ActorUserId = seeded.ActorId,
                Action = "UserDeactivated",
                EntityType = "User",
                EntityId = seeded.TargetId,
                OldValuesJson = "{\"password\":\"hidden\"}",
                NewValuesJson = "{\"token\":\"hidden\"}",
                IpAddress = "127.0.0.1",
                UserAgent = "test-agent",
                CorrelationId = "api-correlation"
            });
            await context.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.GetAsync("/api/admin/audit-logs?action=UserDeactivated");
        var body = await response.Content.ReadAsStringAsync();

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains("UserDeactivated", body, StringComparison.Ordinal);
        Assert.DoesNotContain("oldValuesJson", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("newValuesJson", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ipAddress", body, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("userAgent", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Admin_audit_list_invalid_query_returns_400()
    {
        var seeded = await SeedAdminUsersAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.GetAsync("/api/admin/audit-logs?page=0");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Admin_audit_list_revalidates_current_admin_role()
    {
        var seeded = await SeedAdminUsersAsync();
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            context.Set<IdentityUserRole<Guid>>().RemoveRange(
                context.Set<IdentityUserRole<Guid>>().Where(x => x.UserId == seeded.ActorId));
            await context.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.GetAsync("/api/admin/audit-logs");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_can_get_audit_detail_without_leaking_secrets()
    {
        var seeded = await SeedAdminUsersAsync();
        var auditId = Guid.NewGuid();
        var longUserAgent = new string('a', 5000);
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
            context.AuditLogs.Add(new AuditLog
            {
                Id = auditId,
                ActorUserId = seeded.ActorId,
                Action = "UserDeactivated",
                EntityType = "User",
                EntityId = seeded.TargetId,
                OldValuesJson = "{\"email\":\"user@example.com\",\"accessToken\":\"detail-secret\",\"profile\":{\"security_stamp\":\"stamp-secret\"}}",
                NewValuesJson = "[{\"name\":\"safe\",\"refreshTokenHash\":\"hash-secret\"}]",
                IpAddress = "192.0.2.10",
                UserAgent = longUserAgent,
                CorrelationId = "detail-correlation"
            });
            await context.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.GetAsync($"/api/admin/audit-logs/{auditId}");
        var body = await response.Content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(body);
        var root = document.RootElement;

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("192.0.2.10", root.GetProperty("ipAddress").GetString());
        Assert.Equal("detail-correlation", root.GetProperty("correlationId").GetString());
        Assert.Equal(4096, root.GetProperty("userAgent").GetString()!.Length);
        Assert.Equal("[REDACTED]", root.GetProperty("oldValues").GetProperty("value").GetProperty("accessToken").GetString());
        Assert.Equal("[REDACTED]", root.GetProperty("newValues").GetProperty("value")[0].GetProperty("refreshTokenHash").GetString());
        Assert.DoesNotContain("detail-secret", body, StringComparison.Ordinal);
        Assert.DoesNotContain("stamp-secret", body, StringComparison.Ordinal);
        Assert.DoesNotContain("hash-secret", body, StringComparison.Ordinal);

        using var verificationScope = factory.Services.CreateScope();
        var verificationContext = verificationScope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var persisted = await verificationContext.AuditLogs.SingleAsync(x => x.Id == auditId);
        Assert.Contains("detail-secret", persisted.OldValuesJson, StringComparison.Ordinal);
        Assert.Equal(5000, persisted.UserAgent!.Length);
    }

    [Fact]
    public async Task Anonymous_audit_detail_request_returns_401()
    {
        var response = await factory.CreateClient().GetAsync($"/api/admin/audit-logs/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Non_admin_audit_detail_request_returns_403()
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", CreateToken("User"));

        var response = await client.GetAsync($"/api/admin/audit-logs/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task Admin_audit_detail_for_missing_log_returns_404()
    {
        var seeded = await SeedAdminUsersAsync();
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(
            "Bearer",
            CreateToken("Admin", seeded.ActorId));

        var response = await client.GetAsync($"/api/admin/audit-logs/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private async Task<ApiAdminSeed> SeedAdminUsersAsync()
    {
        var actorId = Guid.NewGuid();
        var targetId = Guid.NewGuid();
        var roleName = $"ApiTestRole-{Guid.NewGuid():N}";
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var adminRole = await context.Set<MotoHubIdentityRole>()
            .FirstAsync(role => role.NormalizedName == "ADMIN");
        context.Set<MotoHubIdentityRole>().Add(new MotoHubIdentityRole
        {
            Id = Guid.NewGuid(),
            Name = roleName,
            NormalizedName = roleName.ToUpperInvariant()
        });
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
        return new ApiAdminSeed(actorId, targetId, Convert.ToBase64String(target.RowVersion), roleName);
    }

    private static MotoHubIdentityUser IdentityUser(Guid id, string userName, string email)
        => new()
        {
            Id = id,
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = true,
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
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

    private sealed record ApiAdminSeed(
        Guid ActorId,
        Guid TargetId,
        string TargetConcurrencyToken,
        string RoleName);
}
