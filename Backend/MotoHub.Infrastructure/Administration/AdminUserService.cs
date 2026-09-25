using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Administration;

public sealed class AdminUserService(
    MotoHubDbContext dbContext,
    ILookupNormalizer lookupNormalizer) : IAdminUserService
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 50;

    public async Task<AdminPagedResponse<AdminUserListItemDto>> ListAsync(
        AdminUserListQuery query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var pageSize = query.PageSize == 0 ? DefaultPageSize : query.PageSize;
        var normalizedSearch = NormalizeSearch(query.Search);
        var normalizedRole = NormalizeRole(query.Role);

        var users =
            from identityUser in dbContext.Set<MotoHubIdentityUser>().AsNoTracking()
            join profile in dbContext.Users.IgnoreQueryFilters().AsNoTracking()
                on identityUser.Id equals profile.Id into profiles
            from profile in profiles.DefaultIfEmpty()
            select new { IdentityUser = identityUser, Profile = profile };

        if (!query.IncludeDeleted)
        {
            users = users.Where(x => x.Profile == null || !x.Profile.IsDeleted);
        }

        if (query.IsActive.HasValue)
        {
            var isActive = query.IsActive.Value;
            users = isActive
                ? users.Where(x => x.Profile != null && x.Profile.IsActive && !x.Profile.IsDeleted)
                : users.Where(x => x.Profile == null || !x.Profile.IsActive || x.Profile.IsDeleted);
        }

        if (query.EmailConfirmed.HasValue)
        {
            var emailConfirmed = query.EmailConfirmed.Value;
            users = users.Where(x => x.IdentityUser.EmailConfirmed == emailConfirmed);
        }

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            users = users.Where(x =>
                x.IdentityUser.NormalizedEmail!.StartsWith(normalizedSearch) ||
                x.IdentityUser.NormalizedUserName!.StartsWith(normalizedSearch));
        }

        if (!string.IsNullOrWhiteSpace(normalizedRole))
        {
            users = users.Where(x =>
                (from userRole in dbContext.Set<IdentityUserRole<Guid>>()
                 join role in dbContext.Set<MotoHubIdentityRole>()
                     on userRole.RoleId equals role.Id
                 where userRole.UserId == x.IdentityUser.Id && role.NormalizedName == normalizedRole
                 select userRole).Any());
        }

        var totalCount = await users.CountAsync(cancellationToken);
        var rows = await users
            .OrderBy(x => x.IdentityUser.NormalizedUserName)
            .ThenBy(x => x.IdentityUser.Id)
            .Skip((query.Page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var rolesByUser = await LoadRolesAsync(rows.Select(x => x.IdentityUser.Id), cancellationToken);

        var items = rows.Select(row => ToListItem(
            row.IdentityUser,
            row.Profile,
            rolesByUser.GetValueOrDefault(row.IdentityUser.Id) ?? Array.Empty<string>())).ToArray();
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)pageSize);
        return new AdminPagedResponse<AdminUserListItemDto>(items, query.Page, pageSize, totalCount, totalPages);
    }

    public async Task<AdminUserDetailDto> GetAsync(Guid userId, CancellationToken cancellationToken)
    {
        var identityUser = await dbContext.Set<MotoHubIdentityUser>()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("El usuario no existe.");
        var profile = await dbContext.Users
            .IgnoreQueryFilters()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);
        var roles = await LoadRolesAsync([userId], cancellationToken);

        return ToDetail(
            identityUser,
            profile,
            roles.GetValueOrDefault(userId) ?? Array.Empty<string>());
    }

    private async Task<Dictionary<Guid, string[]>> LoadRolesAsync(
        IEnumerable<Guid> userIds,
        CancellationToken cancellationToken)
    {
        var ids = userIds.Distinct().ToArray();
        if (ids.Length == 0) return [];

        var roleRows = await (
            from userRole in dbContext.Set<IdentityUserRole<Guid>>().AsNoTracking()
            join role in dbContext.Set<MotoHubIdentityRole>().AsNoTracking()
                on userRole.RoleId equals role.Id
            where ids.Contains(userRole.UserId)
            orderby role.NormalizedName
            select new { userRole.UserId, RoleName = role.Name })
            .ToListAsync(cancellationToken);

        return roleRows
            .Where(x => x.RoleName != null)
            .GroupBy(x => x.UserId)
            .ToDictionary(x => x.Key, x => x.Select(item => item.RoleName!).ToArray());
    }

    private static void ValidateQuery(AdminUserListQuery query)
    {
        if (query.Page < 1)
            throw new ValidationException("Page debe ser mayor o igual que uno.");
        if (query.PageSize < 0 || query.PageSize > MaxPageSize)
            throw new ValidationException($"PageSize debe estar entre cero y {MaxPageSize}.");
        if (query.Search?.Length > 100)
            throw new ValidationException("Search no puede superar 100 caracteres.");
        if (query.Role?.Length > 100)
            throw new ValidationException("Role no puede superar 100 caracteres.");
    }

    private string? NormalizeSearch(string? search)
        => string.IsNullOrWhiteSpace(search)
            ? null
            : lookupNormalizer.NormalizeName(search.Trim());

    private string? NormalizeRole(string? role)
        => string.IsNullOrWhiteSpace(role)
            ? null
            : lookupNormalizer.NormalizeName(role.Trim());

    private static AdminUserListItemDto ToListItem(
        MotoHubIdentityUser identityUser,
        User? profile,
        IReadOnlyCollection<string> roles)
        => new(
            identityUser.Id,
            identityUser.UserName ?? string.Empty,
            identityUser.Email ?? string.Empty,
            identityUser.EmailConfirmed,
            profile?.IsActive == true && !profile.IsDeleted,
            profile?.IsDeleted == true,
            profile is null,
            roles,
            profile?.LastLoginAt,
            profile?.CreatedAt,
            profile?.UpdatedAt,
            ToConcurrencyToken(profile));

    private static AdminUserDetailDto ToDetail(
        MotoHubIdentityUser identityUser,
        User? profile,
        IReadOnlyCollection<string> roles)
        => new(
            identityUser.Id,
            identityUser.UserName ?? string.Empty,
            identityUser.Email ?? string.Empty,
            identityUser.EmailConfirmed,
            profile?.IsActive == true && !profile.IsDeleted,
            profile?.IsDeleted == true,
            profile is null,
            roles,
            profile?.FirstName,
            profile?.LastName,
            profile?.PhoneNumber,
            profile?.Bio,
            profile?.ProfileImageUrl,
            profile?.LastLoginAt,
            profile?.CreatedAt,
            profile?.UpdatedAt,
            identityUser.LockoutEnd,
            ToConcurrencyToken(profile));

    private static string? ToConcurrencyToken(User? profile)
        => profile is null ? null : Convert.ToBase64String(profile.RowVersion);
}
