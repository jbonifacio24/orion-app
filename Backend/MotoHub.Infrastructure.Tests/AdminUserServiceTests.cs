using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
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
        return new SeededIds(missingProfileId, aliceId, deletedId);
    }

    private static MotoHubIdentityUser IdentityUser(Guid id, string userName, string email, bool emailConfirmed)
        => new()
        {
            Id = id,
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = email,
            NormalizedEmail = email.ToUpperInvariant(),
            EmailConfirmed = emailConfirmed
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

    private sealed record SeededIds(Guid MissingProfileUserId, Guid AliceUserId, Guid DeletedUserId);
}
