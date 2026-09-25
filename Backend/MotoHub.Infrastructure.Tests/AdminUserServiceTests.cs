using System.Text.Json;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Auditing;
using MotoHub.Infrastructure.Administration;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class AdminUserServiceTests
{
    [Fact]
    public async Task List_joins_identity_domain_and_roles_with_deterministic_paging()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        await SeedAsync(scope.ServiceProvider);

        var result = await GetService(scope).ListAsync(new AdminUserListQuery(PageSize: 2), default);

        Assert.Equal(3, result.TotalCount);
        Assert.Equal(2, result.Items.Count);
        Assert.Equal(2, result.TotalPages);
        Assert.Equal("alice", result.Items.First().UserName);
        Assert.Equal("AQID", result.Items.First().ConcurrencyToken);
        Assert.Contains("Admin", result.Items.First().Roles);
        Assert.Contains("User", result.Items.First().Roles);
        Assert.DoesNotContain(result.Items, item => item.UserName == "deleted");
        var listJson = JsonSerializer.Serialize(result.Items);
        Assert.DoesNotContain("PasswordHash", listJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SecurityStamp", listJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ConcurrencyStamp", listJson, StringComparison.OrdinalIgnoreCase);

        var secondPage = await GetService(scope).ListAsync(new AdminUserListQuery(Page: 2, PageSize: 2), default);

        var missingProfile = Assert.Single(secondPage.Items);
        Assert.Equal("missing", missingProfile.UserName);
        Assert.True(missingProfile.ProfileMissing);
        Assert.False(missingProfile.IsActive);
        Assert.Null(missingProfile.ConcurrencyToken);
    }

    [Fact]
    public async Task List_supports_search_status_and_role_filters()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var search = await service.ListAsync(new AdminUserListQuery(Search: "BOB"), default);
        var inactive = await service.ListAsync(new AdminUserListQuery(IsActive: false), default);
        var admins = await service.ListAsync(new AdminUserListQuery(Role: "admin"), default);

        Assert.Single(search.Items);
        Assert.Equal("bob", search.Items.Single().UserName);
        Assert.Equal(2, inactive.Items.Count);
        Assert.Contains(inactive.Items, item => item.UserName == "bob");
        Assert.Contains(inactive.Items, item => item.ProfileMissing);
        Assert.Equal(2, inactive.TotalCount);
        Assert.Single(admins.Items);
        Assert.Equal("alice", admins.Items.Single().UserName);
    }

    [Fact]
    public async Task List_filters_effective_active_state_and_deleted_profiles()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var active = await service.ListAsync(new AdminUserListQuery(IsActive: true), default);
        var inactive = await service.ListAsync(new AdminUserListQuery(IsActive: false), default);
        var all = await service.ListAsync(new AdminUserListQuery(IncludeDeleted: true), default);
        var inactiveIncludingDeleted = await service.ListAsync(
            new AdminUserListQuery(IsActive: false, IncludeDeleted: true), default);
        var activeIncludingDeleted = await service.ListAsync(
            new AdminUserListQuery(IsActive: true, IncludeDeleted: true), default);

        Assert.Equal(["alice"], active.Items.Select(item => item.UserName));
        Assert.Equal(["bob", "missing"], inactive.Items.Select(item => item.UserName));
        Assert.Equal(1, active.TotalCount);
        Assert.Equal(2, inactive.TotalCount);
        Assert.Equal(4, all.TotalCount);
        Assert.Contains(all.Items, item => item.UserName == "deleted" && item.IsDeleted && !item.IsActive);
        Assert.Equal(["bob", "deleted", "missing"], inactiveIncludingDeleted.Items.Select(item => item.UserName));
        Assert.DoesNotContain(activeIncludingDeleted.Items, item => item.UserName == "deleted");
    }

    [Fact]
    public async Task List_filters_email_confirmation_and_supports_prefix_search()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var confirmed = await service.ListAsync(new AdminUserListQuery(EmailConfirmed: true), default);
        var unconfirmed = await service.ListAsync(new AdminUserListQuery(EmailConfirmed: false), default);
        var usernamePrefix = await service.ListAsync(new AdminUserListQuery(Search: "ALI"), default);
        var emailPrefix = await service.ListAsync(new AdminUserListQuery(Search: "BOB@"), default);
        var internalFragment = await service.ListAsync(new AdminUserListQuery(Search: "ICE"), default);

        Assert.Equal(["alice", "missing"], confirmed.Items.Select(item => item.UserName));
        Assert.Equal(["bob"], unconfirmed.Items.Select(item => item.UserName));
        Assert.Equal(["alice"], usernamePrefix.Items.Select(item => item.UserName));
        Assert.Equal(["bob"], emailPrefix.Items.Select(item => item.UserName));
        Assert.Empty(internalFragment.Items);
    }

    [Fact]
    public async Task List_validates_page_and_page_size()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        await Assert.ThrowsAsync<ValidationException>(() =>
            service.ListAsync(new AdminUserListQuery(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() =>
            service.ListAsync(new AdminUserListQuery(PageSize: -1), default));
        await Assert.ThrowsAsync<ValidationException>(() =>
            service.ListAsync(new AdminUserListQuery(PageSize: 51), default));
    }

    [Fact]
    public async Task Detail_does_not_expose_identity_secrets_and_marks_missing_profile()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var detail = await service.GetAsync(ids.MissingProfileUserId, default);
        var json = JsonSerializer.Serialize(detail);

        Assert.True(detail.ProfileMissing);
        Assert.False(detail.IsActive);
        Assert.Empty(detail.Roles);
        Assert.DoesNotContain("PasswordHash", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("SecurityStamp", json, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("RefreshToken", json, StringComparison.OrdinalIgnoreCase);
        Assert.Null(detail.ConcurrencyToken);
    }

    [Fact]
    public async Task Detail_maps_roles_soft_delete_state_and_concurrency_token()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedAsync(scope.ServiceProvider);
        var service = GetService(scope);

        var activeDetail = await service.GetAsync(ids.AliceUserId, default);
        var deletedDetail = await service.GetAsync(ids.DeletedUserId, default);

        Assert.Equal(["Admin", "User"], activeDetail.Roles);
        Assert.Equal("AQID", activeDetail.ConcurrencyToken);
        Assert.False(activeDetail.ProfileMissing);
        Assert.True(activeDetail.IsActive);
        Assert.True(deletedDetail.IsDeleted);
        Assert.False(deletedDetail.IsActive);
        Assert.Equal("CQkJ", deletedDetail.ConcurrencyToken);
    }

    [Fact]
    public async Task Detail_returns_not_found_for_missing_identity_user()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();

        await Assert.ThrowsAsync<ResourceNotFoundException>(() =>
            GetService(scope).GetAsync(Guid.NewGuid(), default));
    }

    [Fact]
    public async Task Deactivate_revokes_active_sessions_and_audits_the_change()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);

        var result = await service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, ToToken(target.RowVersion)),
            "127.0.0.1",
            default);

        Assert.False(result.IsActive);
        Assert.NotNull(result.ConcurrencyToken);
        Assert.All(
            await context.RefreshTokens.Where(x => x.UserId == ids.TargetUserId).ToListAsync(),
            token => Assert.NotNull(token.RevokedAt));
        var audit = await context.AuditLogs.SingleAsync(x => x.Action == "UserDeactivated");
        Assert.Equal(ids.TargetUserId, audit.EntityId);
        Assert.Contains("isActive", audit.OldValuesJson, StringComparison.Ordinal);
        Assert.DoesNotContain("token", audit.NewValuesJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("hash", audit.NewValuesJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task Activate_does_not_restore_revoked_sessions_and_is_idempotent()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);

        var deactivated = await service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, ToToken(target.RowVersion)),
            null,
            default);
        var activated = await service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(true, deactivated.ConcurrencyToken),
            null,
            default);
        var noOp = await service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(true, activated.ConcurrencyToken),
            null,
            default);

        Assert.True(activated.IsActive);
        Assert.True(noOp.IsActive);
        Assert.Equal(activated.ConcurrencyToken, noOp.ConcurrencyToken);
        Assert.All(
            await context.RefreshTokens.Where(x => x.UserId == ids.TargetUserId).ToListAsync(),
            token => Assert.NotNull(token.RevokedAt));
        Assert.Equal(1, await context.AuditLogs.CountAsync(x => x.Action == "UserActivated"));
    }

    [Fact]
    public async Task Status_rejects_invalid_stale_and_missing_concurrency_tokens()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);

        await Assert.ThrowsAsync<ValidationException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, null),
            null,
            default));
        await Assert.ThrowsAsync<ValidationException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, "not-base64"),
            null,
            default));
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, ToToken([99])),
            null,
            default));
        Assert.True((await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId)).IsActive);
    }

    [Fact]
    public async Task Status_rejects_missing_deleted_and_self_targets()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            Guid.NewGuid(),
            new AdminUserStatusRequest(false, ToToken([1])),
            null,
            default));
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.MissingProfileUserId,
            new AdminUserStatusRequest(false, ToToken([1])),
            null,
            default));
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.DeletedUserId,
            new AdminUserStatusRequest(false, ToToken([9, 9, 9])),
            null,
            default));
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var actor = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.AliceUserId);
        var selfNoOp = await service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.AliceUserId,
            new AdminUserStatusRequest(true, ToToken(actor.RowVersion)),
            null,
            default);
        Assert.True(selfNoOp.IsActive);
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.AliceUserId,
            new AdminUserStatusRequest(false, selfNoOp.ConcurrencyToken),
            null,
            default));
    }

    [Fact]
    public async Task Mutations_reject_an_actor_without_current_admin_state()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);
        var actor = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.AliceUserId);

        context.Set<IdentityUserRole<Guid>>().RemoveRange(
            context.Set<IdentityUserRole<Guid>>().Where(x => x.UserId == ids.AliceUserId));
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.UpdateStatusAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserStatusRequest(false, ToToken(target.RowVersion)),
            null,
            default));

        var adminRole = await context.Set<MotoHubIdentityRole>().SingleAsync(x => x.NormalizedName == "ADMIN");
        context.Set<IdentityUserRole<Guid>>().Add(new IdentityUserRole<Guid>
        {
            UserId = ids.AliceUserId,
            RoleId = adminRole.Id
        });
        actor.IsActive = false;
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.RevokeSessionsAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            null,
            default));

        actor.IsActive = true;
        actor.IsDeleted = true;
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<AuthenticationException>(() => service.RevokeSessionsAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            null,
            default));
    }

    [Fact]
    public async Task Revoke_sessions_is_target_scoped_idempotent_and_allows_self_revocation()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();

        var targetResult = await service.RevokeSessionsAsync(ids.AliceUserId, ids.TargetUserId, "127.0.0.1", default);
        var secondResult = await service.RevokeSessionsAsync(ids.AliceUserId, ids.TargetUserId, null, default);
        var selfResult = await service.RevokeSessionsAsync(ids.AliceUserId, ids.AliceUserId, null, default);

        Assert.Equal(2, targetResult.RevokedCount);
        Assert.Equal(0, secondResult.RevokedCount);
        Assert.Equal(1, selfResult.RevokedCount);
        Assert.All(
            await context.RefreshTokens.Where(x => x.UserId == ids.TargetUserId || x.UserId == ids.AliceUserId).ToListAsync(),
            token => Assert.NotNull(token.RevokedAt));
        Assert.Contains(
            await context.RefreshTokens.Where(x => x.UserId == ids.BobUserId).ToListAsync(),
            token => token.RevokedAt is null);
        Assert.Equal(3, await context.AuditLogs.CountAsync(x => x.Action == "UserSessionsRevoked"));
        var auditPayloads = await context.AuditLogs
            .Where(x => x.Action == "UserSessionsRevoked")
            .Select(x => x.NewValuesJson)
            .ToListAsync();
        Assert.All(auditPayloads, payload =>
        {
            Assert.Contains("revokedCount", payload, StringComparison.Ordinal);
            Assert.DoesNotContain("token", payload, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("hash", payload, StringComparison.OrdinalIgnoreCase);
        });

        await Assert.ThrowsAsync<ConflictException>(() => service.RevokeSessionsAsync(
            ids.AliceUserId,
            ids.MissingProfileUserId,
            null,
            default));
    }

    [Fact]
    public async Task Replace_roles_applies_complete_set_canonically_and_revokes_sessions()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);

        var result = await service.ReplaceRolesAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserRolesRequest([" user ", "ADMIN", "admin"], ToToken(target.RowVersion)),
            "127.0.0.1",
            default);

        Assert.Equal(["Admin", "User"], result.Roles);
        Assert.All(
            await context.RefreshTokens.Where(x => x.UserId == ids.TargetUserId).ToListAsync(),
            token => Assert.NotNull(token.RevokedAt));
        Assert.Contains(
            await context.Set<IdentityUserRole<Guid>>().Join(
                context.Set<MotoHubIdentityRole>(), userRole => userRole.RoleId, role => role.Id,
                (userRole, role) => new { userRole.UserId, role.Name })
                .Where(x => x.UserId == ids.TargetUserId)
                .ToListAsync(),
            role => role.Name == "Admin");
        Assert.Equal(1, await context.AuditLogs.CountAsync(x => x.Action == "UserRolesChanged"));

        var refreshedTarget = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);
        var removedAdmin = await service.ReplaceRolesAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserRolesRequest(["User"], ToToken(refreshedTarget.RowVersion)),
            null,
            default);
        Assert.Equal(["User"], removedAdmin.Roles);
        Assert.Equal(2, await context.AuditLogs.CountAsync(x => x.Action == "UserRolesChanged"));
    }

    [Fact]
    public async Task Replace_roles_no_op_keeps_token_sessions_and_audit_unchanged()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);
        var expectedToken = ToToken(target.RowVersion);

        var result = await service.ReplaceRolesAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserRolesRequest([], expectedToken),
            null,
            default);

        Assert.Empty(result.Roles);
        Assert.Equal(expectedToken, result.ConcurrencyToken);
        Assert.All(
            await context.RefreshTokens.Where(x => x.UserId == ids.TargetUserId).ToListAsync(),
            token => Assert.Null(token.RevokedAt));
        Assert.Empty(await context.AuditLogs.ToListAsync());
    }

    [Fact]
    public async Task Replace_roles_validates_request_token_and_existing_roles()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);

        await Assert.ThrowsAsync<ValidationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest(null, ToToken(target.RowVersion)), null, default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest([""], ToToken(target.RowVersion)), null, default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest(["Unknown"], ToToken(target.RowVersion)), null, default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest(["User"], null), null, default));
        await Assert.ThrowsAsync<ValidationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest(["User"], "bad-token"), null, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.TargetUserId, new AdminUserRolesRequest(["User"], ToToken([99])), null, default));
    }

    [Fact]
    public async Task Replace_roles_rejects_inconsistent_targets_and_self_admin_removal()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var actor = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.AliceUserId);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, Guid.NewGuid(), new AdminUserRolesRequest(["User"], ToToken([1])), null, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.MissingProfileUserId, new AdminUserRolesRequest(["User"], ToToken([1])), null, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.DeletedUserId, new AdminUserRolesRequest(["User"], ToToken([9, 9, 9])), null, default));
        await Assert.ThrowsAsync<ConflictException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId, ids.AliceUserId, new AdminUserRolesRequest(["User"], ToToken(actor.RowVersion)), null, default));

        var allowed = await service.ReplaceRolesAsync(
            ids.AliceUserId, ids.AliceUserId, new AdminUserRolesRequest(["Admin"], ToToken(actor.RowVersion)), null, default);
        Assert.Equal(["Admin"], allowed.Roles);
    }

    [Fact]
    public async Task Replace_roles_rejects_an_actor_without_current_admin_state()
    {
        await using var provider = CreateProvider();
        await using var scope = provider.CreateAsyncScope();
        var ids = await SeedMutationDataAsync(scope.ServiceProvider);
        SetActor(scope.ServiceProvider, ids.AliceUserId);
        var service = GetService(scope);
        var context = scope.ServiceProvider.GetRequiredService<MotoHubDbContext>();
        var target = await context.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == ids.TargetUserId);
        context.Set<IdentityUserRole<Guid>>().RemoveRange(
            context.Set<IdentityUserRole<Guid>>().Where(x => x.UserId == ids.AliceUserId));
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<AuthenticationException>(() => service.ReplaceRolesAsync(
            ids.AliceUserId,
            ids.TargetUserId,
            new AdminUserRolesRequest(["User"], ToToken(target.RowVersion)),
            null,
            default));
    }

    private static IAdminUserService GetService(AsyncServiceScope scope)
        => scope.ServiceProvider.GetRequiredService<IAdminUserService>();

    private static ServiceProvider CreateProvider()
    {
        var services = new ServiceCollection();
        services.AddDbContext<MotoHubDbContext>(options => options
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning)));
        services.AddIdentityCore<MotoHubIdentityUser>()
            .AddRoles<MotoHubIdentityRole>()
            .AddEntityFrameworkStores<MotoHubDbContext>();
        services.AddHttpContextAccessor();
        services.AddScoped<ISessionRevocationService, SessionRevocationService>();
        services.AddScoped<IAuditService, AuditService>();
        services.AddScoped<IAdminOperationalAccessService, AdminOperationalAccessService>();
        services.AddScoped<IAdminUserService, AdminUserService>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
    }

    private static async Task<SeededIds> SeedAsync(IServiceProvider services)
    {
        var context = services.GetRequiredService<MotoHubDbContext>();
        var adminRole = new MotoHubIdentityRole
        {
            Id = Guid.NewGuid(),
            Name = "Admin",
            NormalizedName = "ADMIN"
        };
        var userRole = new MotoHubIdentityRole
        {
            Id = Guid.NewGuid(),
            Name = "User",
            NormalizedName = "USER"
        };
        var aliceId = Guid.NewGuid();
        var bobId = Guid.NewGuid();
        var deletedId = Guid.NewGuid();
        var missingProfileId = Guid.NewGuid();
        context.Set<MotoHubIdentityRole>().AddRange(adminRole, userRole);
        context.Set<MotoHubIdentityUser>().AddRange(
            IdentityUser(aliceId, "alice", "alice@example.com", true),
            IdentityUser(bobId, "bob", "bob@example.com", false),
            IdentityUser(deletedId, "deleted", "deleted@example.com", true),
            IdentityUser(missingProfileId, "missing", "missing@example.com", true));
        context.Set<IdentityUserRole<Guid>>().AddRange(
            new IdentityUserRole<Guid> { UserId = aliceId, RoleId = adminRole.Id },
            new IdentityUserRole<Guid> { UserId = aliceId, RoleId = userRole.Id },
            new IdentityUserRole<Guid> { UserId = bobId, RoleId = userRole.Id });
        context.Users.AddRange(
            DomainUser(aliceId, "alice", "alice@example.com", true, rowVersion: [1, 2, 3]),
            DomainUser(bobId, "bob", "bob@example.com", false, rowVersion: [4, 5, 6]),
            DomainUser(deletedId, "deleted", "deleted@example.com", true, isDeleted: true, rowVersion: [9, 9, 9]));
        await context.SaveChangesAsync();
        return new SeededIds(missingProfileId, aliceId, deletedId, Guid.Empty, bobId);
    }

    private static async Task<SeededIds> SeedMutationDataAsync(IServiceProvider services)
    {
        var ids = await SeedAsync(services);
        var context = services.GetRequiredService<MotoHubDbContext>();
        var targetId = Guid.NewGuid();
        context.Set<MotoHubIdentityUser>().Add(IdentityUser(targetId, "target", "target@example.com", true));
        context.Users.Add(DomainUser(targetId, "target", "target@example.com", true, rowVersion: [7, 8, 9]));
        context.RefreshTokens.AddRange(
            RefreshToken(targetId, "target-active-1"),
            RefreshToken(targetId, "target-active-2"),
            RefreshToken(ids.AliceUserId, "alice-active"),
            RefreshToken(ids.BobUserId, "bob-active"));
        await context.SaveChangesAsync();
        return ids with { TargetUserId = targetId };
    }

    private static RefreshToken RefreshToken(Guid userId, string tokenHash)
        => new()
        {
            UserId = userId,
            TokenHash = tokenHash,
            ExpiresAt = DateTimeOffset.UtcNow.AddDays(1)
        };

    private static void SetActor(IServiceProvider services, Guid actorUserId)
    {
        services.GetRequiredService<IHttpContextAccessor>().HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim(ClaimTypes.NameIdentifier, actorUserId.ToString())], "test"))
        };
    }

    private static string ToToken(byte[] value) => Convert.ToBase64String(value);

    private static MotoHubIdentityUser IdentityUser(Guid id, string userName, string email, bool emailConfirmed)
        => new()
        {
            Id = id,
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = emailConfirmed,
            SecurityStamp = Guid.NewGuid().ToString(),
            ConcurrencyStamp = Guid.NewGuid().ToString()
        };

    private static Domain.User DomainUser(
        Guid id,
        string userName,
        string email,
        bool isActive,
        bool isDeleted = false,
        byte[]? rowVersion = null)
        => new(id)
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            IsActive = isActive,
            IsDeleted = isDeleted,
            RowVersion = rowVersion ?? []
        };

    private sealed record SeededIds(
        Guid MissingProfileUserId,
        Guid AliceUserId,
        Guid DeletedUserId,
        Guid TargetUserId,
        Guid BobUserId);
}
