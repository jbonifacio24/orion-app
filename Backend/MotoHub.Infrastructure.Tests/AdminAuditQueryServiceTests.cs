using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Administration;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class AdminAuditQueryServiceTests
{
    [Fact]
    public async Task List_uses_default_paging_deterministic_order_and_small_dto()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var result = await service.ListAsync(ids.ActorId, new AdminAuditLogQuery(), default);

        Assert.Equal(20, result.PageSize);
        Assert.Equal(5, result.TotalCount);
        Assert.Equal(5, result.Items.Count);
        Assert.Equal(
            result.Items.OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id),
            result.Items);
        Assert.All(
            result.Items.Where(x => x.ActorUserId == ids.ActorId),
            item => Assert.Equal("actor-name", item.ActorDisplay));
        Assert.Equal("domain-only", result.Items.Single(x => x.ActorUserId == ids.DomainOnlyActorId).ActorDisplay);
        Assert.Null(result.Items.Single(x => x.ActorUserId == null).ActorDisplay);

        var json = System.Text.Json.JsonSerializer.Serialize(result.Items);
        Assert.DoesNotContain("OldValuesJson", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("NewValuesJson", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("IpAddress", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("UserAgent", json, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task List_paginates_and_applies_all_filters_with_utc_boundaries()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var start = new DateTimeOffset(2026, 9, 25, 10, 0, 0, TimeSpan.Zero);
        var end = start.AddHours(1);

        var page = await service.ListAsync(ids.ActorId, new AdminAuditLogQuery(Page: 2, PageSize: 2), default);
        var filtered = await service.ListAsync(
            ids.ActorId,
            new AdminAuditLogQuery(
                PageSize: 1,
                ActorUserId: ids.ActorId,
                Action: "UserDeactivated",
                EntityType: "User",
                EntityId: ids.EntityId,
                From: start,
                To: end,
                CorrelationId: "corr-match"),
            default);

        Assert.Equal(2, page.Items.Count);
        Assert.Equal(3, page.TotalPages);
        var item = Assert.Single(filtered.Items);
        Assert.Equal("UserDeactivated", item.Action);
        Assert.Equal(ids.EntityId, item.EntityId);

        var empty = await service.ListAsync(
            ids.ActorId,
            new AdminAuditLogQuery(From: end, To: end),
            default);
        Assert.Empty(empty.Items);
        Assert.Equal(0, empty.TotalCount);
    }

    [Fact]
    public async Task List_validates_page_size_and_date_range()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        await Assert.ThrowsAsync<ValidationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(PageSize: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(PageSize: 51), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ListAsync(
            ids.ActorId,
            new AdminAuditLogQuery(From: DateTimeOffset.UtcNow, To: DateTimeOffset.UtcNow.AddMinutes(-1)),
            default));
    }

    [Fact]
    public async Task List_requires_current_operational_admin_and_is_read_only()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var before = await context.AuditLogs.Select(x => x.Id).ToListAsync();

        var result = await service.ListAsync(ids.ActorId, new AdminAuditLogQuery(), default);
        Assert.NotEmpty(result.Items);
        Assert.Equal(before, await context.AuditLogs.Select(x => x.Id).ToListAsync());

        context.Set<IdentityUserRole<Guid>>().RemoveRange(
            context.Set<IdentityUserRole<Guid>>().Where(x => x.UserId == ids.ActorId));
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(), default));
    }

    [Fact]
    public async Task List_rejects_inactive_and_deleted_admin_profiles()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var actor = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.ActorId);

        actor.IsActive = false;
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(), default));

        actor.IsActive = true;
        actor.IsDeleted = true;
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.ListAsync(
            ids.ActorId, new AdminAuditLogQuery(), default));
    }

    [Fact]
    public async Task GetById_returns_sanitized_detail_and_does_not_write()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var audit = await context.AuditLogs.FirstAsync(x => x.ActorUserId == ids.ActorId && x.Action == "UserDeactivated");
        var before = await context.AuditLogs.Select(x => new { x.Id, x.OldValuesJson, x.NewValuesJson }).ToListAsync();

        var result = await service.GetByIdAsync(ids.ActorId, audit.Id, default);

        Assert.Equal(audit.Id, result.Id);
        Assert.Equal("actor-name", result.ActorDisplay);
        Assert.Equal(AuditPayloadStatus.Redacted, result.OldValues!.Status);
        Assert.DoesNotContain("hidden", System.Text.Json.JsonSerializer.Serialize(result.OldValues), StringComparison.Ordinal);
        Assert.Equal(before, await context.AuditLogs.Select(x => new { x.Id, x.OldValuesJson, x.NewValuesJson }).ToListAsync());
    }

    [Fact]
    public async Task GetById_returns_not_found_and_handles_unresolvable_actor()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var audit = await context.AuditLogs.SingleAsync(x => x.ActorUserId == null);

        var result = await service.GetByIdAsync(ids.ActorId, audit.Id, default);

        Assert.Null(result.ActorUserId);
        Assert.Null(result.ActorDisplay);
        Assert.Null(result.OldValues);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetByIdAsync(
            ids.ActorId, Guid.NewGuid(), default));
    }

    [Fact]
    public async Task GetById_keeps_soft_deleted_actor_log_visible()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var audit = await context.AuditLogs.SingleAsync(x => x.ActorUserId == ids.SoftDeletedActorId);

        var result = await service.GetByIdAsync(ids.ActorId, audit.Id, default);

        Assert.Equal(ids.SoftDeletedActorId, result.ActorUserId);
        Assert.Equal("deleted-name", result.ActorDisplay);
    }

    private static IAdminAuditQueryService GetService(AsyncServiceScope scope)
        => scope.ServiceProvider.GetRequiredService<IAdminAuditQueryService>();

    private static ServiceProvider CreateProvider()
    {
        var services = new ServiceCollection();
        services.AddDbContext<MotoHubDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<MotoHubIdentityUser>()
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>();
        services.AddScoped<IAdminOperationalAccessService, AdminOperationalAccessService>();
        services.AddScoped<AuditPayloadSanitizer>();
        services.AddScoped<IAdminAuditQueryService, AdminAuditQueryService>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }

    private static async Task<SeededAuditIds> SeedAsync(IServiceProvider services)
    {
        var context = services.GetRequiredService<MotoHubDbContext>();
        var adminRole = new MotoHubIdentityRole
        {
            Id = Guid.NewGuid(),
            Name = "Admin",
            NormalizedName = "ADMIN"
        };
        var actorId = Guid.NewGuid();
        var softDeletedActorId = Guid.NewGuid();
        var domainOnlyActorId = Guid.NewGuid();
        var entityId = Guid.NewGuid();
        var start = new DateTimeOffset(2026, 9, 25, 10, 0, 0, TimeSpan.Zero);

        context.Set<MotoHubIdentityRole>().Add(adminRole);
        context.Set<MotoHubIdentityUser>().AddRange(
            IdentityUser(actorId, "actor-name", "actor@example.com"),
            IdentityUser(softDeletedActorId, "deleted-name", "deleted@example.com"));
        context.Set<IdentityUserRole<Guid>>().Add(new IdentityUserRole<Guid>
        {
            UserId = actorId,
            RoleId = adminRole.Id
        });
        context.Users.AddRange(
            DomainUser(actorId, "actor-domain", "actor@example.com"),
            DomainUser(softDeletedActorId, "deleted-domain", "deleted@example.com", true),
            DomainUser(domainOnlyActorId, "domain-only", "domain-only@example.com"));
        context.AuditLogs.AddRange(
            new AuditLog
            {
                ActorUserId = actorId,
                Action = "UserDeactivated",
                EntityType = "User",
                EntityId = entityId,
                CorrelationId = "corr-match",
                OldValuesJson = "{\"password\":\"hidden\"}",
                IpAddress = "127.0.0.1",
                UserAgent = "test-agent",
                CreatedAt = start
            },
            new AuditLog
            {
                ActorUserId = actorId,
                Action = "UserActivated",
                EntityType = "User",
                EntityId = Guid.NewGuid(),
                CreatedAt = start
            },
            new AuditLog
            {
                ActorUserId = softDeletedActorId,
                Action = "UserRolesChanged",
                EntityType = "User",
                EntityId = Guid.NewGuid(),
                CreatedAt = start.AddMinutes(1)
            },
            new AuditLog
            {
                ActorUserId = domainOnlyActorId,
                Action = "UserSessionsRevoked",
                EntityType = "User",
                EntityId = Guid.NewGuid(),
                CreatedAt = start.AddMinutes(2)
            },
            new AuditLog
            {
                ActorUserId = null,
                Action = "AdminRoleCreated",
                EntityType = "MotoHubIdentityRole",
                EntityId = Guid.NewGuid(),
                CreatedAt = start.AddMinutes(2)
            });
        await context.SaveChangesAsync();
        return new SeededAuditIds(actorId, softDeletedActorId, domainOnlyActorId, entityId);
    }

    private static MotoHubIdentityUser IdentityUser(Guid id, string userName, string email)
        => new()
        {
            Id = id,
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
        };

    private static User DomainUser(Guid id, string userName, string email, bool isDeleted = false)
        => new(id)
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            IsActive = true,
            IsDeleted = isDeleted
        };

    private sealed record SeededAuditIds(
        Guid ActorId,
        Guid SoftDeletedActorId,
        Guid DomainOnlyActorId,
        Guid EntityId);
}
