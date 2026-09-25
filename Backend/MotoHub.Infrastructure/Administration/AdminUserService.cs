using System.Security.Cryptography;
using System.Text.Json;
using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Administration;

public sealed class AdminUserService(
    MotoHubDbContext dbContext,
    ILookupNormalizer lookupNormalizer,
    UserManager<MotoHubIdentityUser> userManager,
    RoleManager<MotoHubIdentityRole> roleManager,
    ISessionRevocationService sessionRevocationService,
    IAuditService auditService) : IAdminUserService
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 50;
    private const string UserActivatedAction = "UserActivated";
    private const string UserDeactivatedAction = "UserDeactivated";
    private const string UserSessionsRevokedAction = "UserSessionsRevoked";

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

    public async Task<AdminUserStatusResponse> UpdateStatusAsync(
        Guid actorUserId,
        Guid userId,
        AdminUserStatusRequest request,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        if (request is null)
            throw new ValidationException("El request de estado es obligatorio.");

        await EnsureOperationalAdminAsync(actorUserId, cancellationToken);
        var identityUser = await FindIdentityUserAsync(userId, cancellationToken);
        var profile = await FindMutableProfileAsync(userId, cancellationToken);
        var expectedRowVersion = DecodeConcurrencyToken(request.ConcurrencyToken);

        if (!CryptographicOperations.FixedTimeEquals(profile.RowVersion, expectedRowVersion))
            throw new ConflictException("El usuario fue modificado por otro proceso.");

        if (profile.IsActive == request.IsActive)
        {
            if (!request.IsActive && actorUserId == userId)
                throw new ConflictException("Un administrador no puede desactivarse a sí mismo.");

            return new AdminUserStatusResponse(userId, profile.IsActive, ToConcurrencyToken(profile));
        }

        if (!request.IsActive && actorUserId == userId)
            throw new ConflictException("Un administrador no puede desactivarse a sí mismo.");

        await using var transaction = await BeginTransactionIfRelationalAsync(
            !request.IsActive && profile.IsActive ? IsolationLevel.Serializable : null,
            cancellationToken);
        try
        {
            if (!request.IsActive && profile.IsActive &&
                await IsOperationalAdminAsync(userId, cancellationToken) &&
                !await HasOtherOperationalAdminAsync(userId, cancellationToken))
            {
                throw new ConflictException("No se puede desactivar el último administrador operativo.");
            }

            dbContext.Entry(profile).Property(x => x.RowVersion).OriginalValue = expectedRowVersion;
            var previousState = profile.IsActive;
            profile.IsActive = request.IsActive;

            var revokedCount = request.IsActive
                ? 0
                : await sessionRevocationService.RevokeAllAsync(
                    userId,
                    "Admin user deactivated",
                    ipAddress,
                    cancellationToken);

            if (request.IsActive || revokedCount == 0)
                await SaveWithConcurrencyHandlingAsync(cancellationToken);

            await auditService.WriteAsync(
                new AuditEntry(
                    request.IsActive ? UserActivatedAction : UserDeactivatedAction,
                    nameof(User),
                    userId,
                    OldValuesJson: JsonSerializer.Serialize(new { isActive = previousState }),
                    NewValuesJson: JsonSerializer.Serialize(new { isActive = request.IsActive })),
                cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            return new AdminUserStatusResponse(userId, profile.IsActive, ToConcurrencyToken(profile));
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("El usuario fue modificado por otro proceso.");
        }
    }

    public async Task<AdminSessionRevocationResponse> RevokeSessionsAsync(
        Guid actorUserId,
        Guid userId,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        await EnsureOperationalAdminAsync(actorUserId, cancellationToken);
        await FindIdentityUserAsync(userId, cancellationToken);
        await FindMutableProfileAsync(userId, cancellationToken);

        await using var transaction = await BeginTransactionIfRelationalAsync(cancellationToken);
        var revokedCount = await sessionRevocationService.RevokeAllAsync(
            userId,
            "Admin session revocation",
            ipAddress,
            cancellationToken);

        await auditService.WriteAsync(
            new AuditEntry(
                UserSessionsRevokedAction,
                nameof(User),
                userId,
                NewValuesJson: JsonSerializer.Serialize(new { revokedCount })),
            cancellationToken);

        if (transaction is not null)
            await transaction.CommitAsync(cancellationToken);

        return new AdminSessionRevocationResponse(userId, revokedCount);
    }

    public async Task<AdminUserRolesResponse> ReplaceRolesAsync(
        Guid actorUserId,
        Guid userId,
        AdminUserRolesRequest request,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        if (request is null)
            throw new ValidationException("El request de roles es obligatorio.");
        await EnsureOperationalAdminAsync(actorUserId, cancellationToken);
        var desiredRoleNames = NormalizeRequestedRoles(request.Roles);
        var desiredRoles = await ResolveRolesAsync(desiredRoleNames, cancellationToken);
        var identityUser = await FindIdentityUserAsync(userId, cancellationToken);
        var profile = await FindMutableProfileAsync(userId, cancellationToken);
        var expectedRowVersion = DecodeConcurrencyToken(request.ConcurrencyToken);
        if (!CryptographicOperations.FixedTimeEquals(profile.RowVersion, expectedRowVersion))
            throw new ConflictException("El usuario fue modificado por otro proceso.");

        var currentRoleNames = (await userManager.GetRolesAsync(identityUser))
            .OrderBy(role => lookupNormalizer.NormalizeName(role), StringComparer.Ordinal)
            .ToArray();
        var currentRoleKeys = currentRoleNames
            .Select(role => lookupNormalizer.NormalizeName(role)!)
            .ToHashSet(StringComparer.Ordinal);
        var desiredRoleKeys = desiredRoles
            .Select(role => lookupNormalizer.NormalizeName(role.Name)!)
            .ToHashSet(StringComparer.Ordinal);
        var rolesToRemove = currentRoleNames
            .Where(role => !desiredRoleKeys.Contains(lookupNormalizer.NormalizeName(role)!))
            .ToArray();
        var rolesToAdd = desiredRoles
            .Where(role => !currentRoleKeys.Contains(lookupNormalizer.NormalizeName(role.Name)!))
            .Select(role => role.Name!)
            .ToArray();
        var rolesChanged = rolesToRemove.Length > 0 || rolesToAdd.Length > 0;
        if (!rolesChanged)
        {
            return new AdminUserRolesResponse(userId, currentRoleNames, ToConcurrencyToken(profile));
        }

        var removesAdmin = rolesToRemove.Any(role =>
            string.Equals(lookupNormalizer.NormalizeName(role), lookupNormalizer.NormalizeName(AdminSecurity.AdminRole), StringComparison.Ordinal));
        if (actorUserId == userId && removesAdmin)
            throw new ConflictException("Un administrador no puede quitarse a sí mismo el rol Admin.");

        await using var transaction = await BeginTransactionIfRelationalAsync(
            removesAdmin ? IsolationLevel.Serializable : null,
            cancellationToken);
        try
        {
            if (removesAdmin && await IsOperationalAdminAsync(userId, cancellationToken) &&
                !await HasOtherOperationalAdminAsync(userId, cancellationToken))
            {
                throw new ConflictException("No se puede eliminar el último administrador operativo.");
            }

            dbContext.Entry(profile).Property(x => x.RowVersion).OriginalValue = expectedRowVersion;
            if (rolesToRemove.Length > 0)
            {
                EnsureIdentitySuccess(
                    await userManager.RemoveFromRolesAsync(identityUser, rolesToRemove));
            }
            if (rolesToAdd.Length > 0)
            {
                EnsureIdentitySuccess(
                    await userManager.AddToRolesAsync(identityUser, rolesToAdd));
            }
            profile.UpdatedAt = DateTimeOffset.UtcNow;

            var revokedCount = await sessionRevocationService.RevokeAllAsync(
                userId,
                "Admin roles changed",
                ipAddress,
                cancellationToken);
            if (revokedCount == 0)
                await SaveWithConcurrencyHandlingAsync(cancellationToken);

            var finalRoles = desiredRoles
                .Select(role => role.Name!)
                .OrderBy(role => lookupNormalizer.NormalizeName(role), StringComparer.Ordinal)
                .ToArray();
            await auditService.WriteAsync(
                new AuditEntry(
                    "UserRolesChanged",
                    nameof(User),
                    userId,
                    OldValuesJson: JsonSerializer.Serialize(new { roles = currentRoleNames }),
                    NewValuesJson: JsonSerializer.Serialize(new { roles = finalRoles, revokedSessionCount = revokedCount })),
                cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            return new AdminUserRolesResponse(userId, finalRoles, ToConcurrencyToken(profile));
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("El usuario fue modificado por otro proceso.");
        }
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

    private string[] NormalizeRequestedRoles(IReadOnlyCollection<string>? roles)
    {
        if (roles is null)
            throw new ValidationException("Roles es obligatorio.");

        var normalizedRoles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var role in roles)
        {
            if (string.IsNullOrWhiteSpace(role) || role.Trim().Length > 100)
                throw new ValidationException("Cada rol debe ser un nombre válido de hasta 100 caracteres.");
            normalizedRoles.Add(role.Trim());
        }

        return normalizedRoles.ToArray();
    }

    private async Task<MotoHubIdentityRole[]> ResolveRolesAsync(
        IEnumerable<string> requestedRoles,
        CancellationToken cancellationToken)
    {
        var roles = new List<MotoHubIdentityRole>();
        foreach (var requestedRole in requestedRoles)
        {
            var normalizedRole = lookupNormalizer.NormalizeName(requestedRole);
            var role = await roleManager.Roles
                .FirstOrDefaultAsync(x => x.NormalizedName == normalizedRole, cancellationToken);
            if (role is null)
                throw new ValidationException($"El rol '{requestedRole}' no existe.");
            roles.Add(role);
        }

        return roles
            .OrderBy(role => lookupNormalizer.NormalizeName(role.Name), StringComparer.Ordinal)
            .ToArray();
    }

    private async Task EnsureOperationalAdminAsync(Guid actorUserId, CancellationToken cancellationToken)
    {
        var identityActor = await dbContext.Set<MotoHubIdentityUser>()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == actorUserId, cancellationToken);
        if (identityActor is null)
            throw new AuthenticationException("El administrador autenticado ya no está disponible.", 403);

        var adminRole = lookupNormalizer.NormalizeName(AdminSecurity.AdminRole);
        var hasAdminRole = await (
            from userRole in dbContext.Set<IdentityUserRole<Guid>>().AsNoTracking()
            join role in dbContext.Set<MotoHubIdentityRole>().AsNoTracking()
                on userRole.RoleId equals role.Id
            where userRole.UserId == actorUserId && role.NormalizedName == adminRole
            select userRole).AnyAsync(cancellationToken);
        if (!hasAdminRole)
            throw new AuthenticationException("El administrador autenticado ya no está autorizado.", 403);

        var profile = await dbContext.Users
            .IgnoreQueryFilters()
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == actorUserId, cancellationToken);
        if (profile is not { IsActive: true, IsDeleted: false })
            throw new AuthenticationException("El administrador autenticado ya no está operativo.", 403);
    }

    private async Task<bool> IsOperationalAdminAsync(Guid userId, CancellationToken cancellationToken)
        => await (
            from userRole in dbContext.Set<IdentityUserRole<Guid>>().AsNoTracking()
            join role in dbContext.Set<MotoHubIdentityRole>().AsNoTracking()
                on userRole.RoleId equals role.Id
            join profile in dbContext.Users.IgnoreQueryFilters().AsNoTracking()
                on userRole.UserId equals profile.Id
            where userRole.UserId == userId &&
                  role.NormalizedName == lookupNormalizer.NormalizeName(AdminSecurity.AdminRole) &&
                  profile.IsActive && !profile.IsDeleted
            select userRole.UserId).AnyAsync(cancellationToken);

    private async Task<bool> HasOtherOperationalAdminAsync(Guid excludedUserId, CancellationToken cancellationToken)
        => await (
            from userRole in dbContext.Set<IdentityUserRole<Guid>>().AsNoTracking()
            join role in dbContext.Set<MotoHubIdentityRole>().AsNoTracking()
                on userRole.RoleId equals role.Id
            join profile in dbContext.Users.IgnoreQueryFilters().AsNoTracking()
                on userRole.UserId equals profile.Id
            where userRole.UserId != excludedUserId &&
                  role.NormalizedName == lookupNormalizer.NormalizeName(AdminSecurity.AdminRole) &&
                  profile.IsActive && !profile.IsDeleted
            select userRole.UserId).AnyAsync(cancellationToken);

    private static void EnsureIdentitySuccess(IdentityResult result)
    {
        if (!result.Succeeded)
            throw new ConflictException("No se pudieron actualizar los roles del usuario.");
    }

    private async Task<MotoHubIdentityUser> FindIdentityUserAsync(Guid userId, CancellationToken cancellationToken)
        => await dbContext.Set<MotoHubIdentityUser>()
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("El usuario no existe.");

    private async Task<User> FindMutableProfileAsync(Guid userId, CancellationToken cancellationToken)
    {
        var profile = await dbContext.Users
            .IgnoreQueryFilters()
            .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);
        if (profile is null)
            throw new ConflictException("El usuario no tiene un perfil administrativo consistente.");
        if (profile.IsDeleted)
            throw new ConflictException("El usuario está eliminado.");
        return profile;
    }

    private async Task SaveWithConcurrencyHandlingAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("El usuario fue modificado por otro proceso.");
        }
    }

    private Task<IDbContextTransaction?> BeginTransactionIfRelationalAsync(CancellationToken cancellationToken)
        => BeginTransactionIfRelationalAsync(null, cancellationToken);

    private async Task<IDbContextTransaction?> BeginTransactionIfRelationalAsync(
        IsolationLevel? isolationLevel,
        CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational())
            return null;
        return isolationLevel.HasValue
            ? await dbContext.Database.BeginTransactionAsync(isolationLevel.Value, cancellationToken)
            : await dbContext.Database.BeginTransactionAsync(cancellationToken);
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
            ToNullableConcurrencyToken(profile));

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
            ToNullableConcurrencyToken(profile));

    private static string ToConcurrencyToken(User profile)
        => Convert.ToBase64String(profile.RowVersion);

    private static string? ToNullableConcurrencyToken(User? profile)
        => profile is null ? null : ToConcurrencyToken(profile);

    private static byte[] DecodeConcurrencyToken(string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
            throw new ValidationException("ConcurrencyToken es obligatorio.");

        try
        {
            return Convert.FromBase64String(token);
        }
        catch (FormatException)
        {
            throw new ValidationException("ConcurrencyToken debe ser Base64 válido.");
        }
    }
}
