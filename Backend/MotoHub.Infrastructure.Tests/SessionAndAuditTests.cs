using System.Net;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class SessionAndAuditTests
{
    [Fact]
    public async Task Revoking_all_sessions_leaves_previous_revocations_intact()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var userId = Guid.NewGuid();
        context.Users.Add(new User(userId)
        {
            UserName = "session-user",
            NormalizedUserName = "SESSION-USER",
            Email = "session@example.com",
            NormalizedEmail = "SESSION@EXAMPLE.COM"
        });
        var alreadyRevoked = new RefreshToken
        {
            UserId = userId,
            TokenHash = "revoked-hash",
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(1),
            RevokedAt = DateTimeOffset.UtcNow.AddMinutes(-1),
            RevocationReason = "Previous reason"
        };
        context.RefreshTokens.AddRange(
            alreadyRevoked,
            new RefreshToken { UserId = userId, TokenHash = "active-hash-1", ExpiresAt = DateTimeOffset.UtcNow.AddDays(1) },
            new RefreshToken { UserId = userId, TokenHash = "active-hash-2", ExpiresAt = DateTimeOffset.UtcNow.AddDays(1) });
        await context.SaveChangesAsync();

        var count = await scope.ServiceProvider.GetRequiredService<ISessionRevocationService>()
            .RevokeAllAsync(userId, "Security action", "127.0.0.1", default);

        Assert.Equal(2, count);
        var tokens = await context.RefreshTokens.Where(x => x.UserId == userId).ToListAsync();
        Assert.Equal("Previous reason", tokens.Single(x => x.TokenHash == "revoked-hash").RevocationReason);
        Assert.All(tokens.Where(x => x.TokenHash != "revoked-hash"), token =>
        {
            Assert.NotNull(token.RevokedAt);
            Assert.Equal("Security action", token.RevocationReason);
            Assert.Equal("127.0.0.1", token.RevokedByIp);
        });
    }

    [Fact]
    public async Task Audit_service_persists_context_without_sensitive_payloads()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var actorId = Guid.NewGuid();
        var context = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, actorId.ToString())], "test"))
        };
        context.Connection.RemoteIpAddress = IPAddress.Parse("127.0.0.1");
        context.Request.Headers.UserAgent = "MotoHub.Tests";
        context.Request.Headers["X-Correlation-ID"] = "correlation-1";
        scope.ServiceProvider.GetRequiredService<IHttpContextAccessor>().HttpContext = context;

        var entityId = Guid.NewGuid();
        await scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
            new AuditEntry("AdminRoleAssigned", "MotoHubIdentityUser", entityId, NewValuesJson: "{\"role\":\"Admin\"}"),
            default);

        var audit = await scope.ServiceProvider.GetRequiredService<MotoHubDbContext>().AuditLogs.SingleAsync();
        Assert.Equal(actorId, audit.ActorUserId);
        Assert.Equal(entityId, audit.EntityId);
        Assert.Equal("AdminRoleAssigned", audit.Action);
        Assert.Equal("127.0.0.1", audit.IpAddress);
        Assert.Equal("MotoHub.Tests", audit.UserAgent);
        Assert.Equal("correlation-1", audit.CorrelationId);
        Assert.DoesNotContain("token", audit.NewValuesJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Audit_service_rejects_sensitive_payloads()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry("Unsafe", "Test", Guid.NewGuid(), NewValuesJson: "{\"accessToken\":\"value\"}"),
                default));

        Assert.Empty(await scope.ServiceProvider.GetRequiredService<MotoHubDbContext>().AuditLogs.ToListAsync());
    }

    [Theory]
    [InlineData("password")]
    [InlineData("accessToken")]
    [InlineData("refreshToken")]
    [InlineData("authorization")]
    [InlineData("apiKey")]
    [InlineData("credential")]
    [InlineData("bearer")]
    [InlineData("jwt")]
    [InlineData("privateKey")]
    [InlineData("connectionString")]
    [InlineData("clientSecret")]
    [InlineData("ApiKey")]
    [InlineData("API_KEY")]
    [InlineData("private_key")]
    [InlineData("connection_string")]
    [InlineData("client_secret")]
    public async Task Audit_service_rejects_sensitive_property_names(string propertyName)
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry("Unsafe", "Test", Guid.NewGuid(), NewValuesJson: $"{{\"{propertyName}\":\"value\"}}"),
                default));
    }

    [Fact]
    public async Task Audit_service_rejects_sensitive_properties_nested_in_objects_and_arrays()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry(
                    "Unsafe",
                    "Test",
                    Guid.NewGuid(),
                    NewValuesJson: "{\"request\":{\"authentication\":{\"apiKey\":\"value\"}},\"items\":[{\"private_key\":\"value\"}]}"),
                default));
    }

    [Fact]
    public async Task Audit_service_allows_non_sensitive_text_and_normal_properties()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
            new AuditEntry(
                "NewsUpdated",
                "News",
                Guid.NewGuid(),
                NewValuesJson: "{\"title\":\"News title\",\"status\":\"Published\",\"description\":\"Invalid token reported by remote service\"}"),
            default);

        Assert.Single(await scope.ServiceProvider.GetRequiredService<MotoHubDbContext>().AuditLogs.ToListAsync());
    }

    [Fact]
    public async Task Audit_service_keeps_rejecting_sensitive_terms_in_invalid_json()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry("Unsafe", "Test", Guid.NewGuid(), NewValuesJson: "not-json token=value"),
                default));
    }

    [Theory]
    [InlineData("api_key=abc123")]
    [InlineData("API_KEY=abc123")]
    [InlineData("api-key=abc123")]
    [InlineData("private_key=abc123")]
    [InlineData("private-key=abc123")]
    [InlineData("connection_string=abc123")]
    [InlineData("connection-string=abc123")]
    [InlineData("client_secret=abc123")]
    [InlineData("access_token=abc123")]
    [InlineData("refresh_token=abc123")]
    [InlineData("jwt=abc123")]
    [InlineData("credential=abc123")]
    [InlineData("api_key: abc123")]
    [InlineData("private_key: abc123")]
    public async Task Audit_service_rejects_sensitive_assignments_in_invalid_json(string payload)
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry("Unsafe", "Test", Guid.NewGuid(), NewValuesJson: payload),
                default));
    }

    [Fact]
    public async Task Audit_service_allows_non_sensitive_unstructured_metadata()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
            new AuditEntry("NewsUpdated", "News", Guid.NewGuid(), NewValuesJson: "status=Published; message=News updated"),
            default);

        Assert.Single(await scope.ServiceProvider.GetRequiredService<MotoHubDbContext>().AuditLogs.ToListAsync());
    }

    [Fact]
    public async Task Audit_service_honors_cancellation()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() =>
            scope.ServiceProvider.GetRequiredService<IAuditService>().WriteAsync(
                new AuditEntry("Cancelled", "Test", Guid.NewGuid()),
                new CancellationToken(true)));

        Assert.Empty(await scope.ServiceProvider.GetRequiredService<MotoHubDbContext>().AuditLogs.ToListAsync());
    }

    private static ServiceProvider CreateProvider()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddHttpContextAccessor();
        services.AddDbContext<MotoHubDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<IAuditService, AuditService>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }
}
