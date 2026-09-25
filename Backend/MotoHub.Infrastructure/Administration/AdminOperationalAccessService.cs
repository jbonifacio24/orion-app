using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Administration;

public sealed class AdminOperationalAccessService(
    MotoHubDbContext dbContext,
    ILookupNormalizer lookupNormalizer) : IAdminOperationalAccessService
{
    public async Task EnsureOperationalAdminAsync(
        Guid actorUserId,
        CancellationToken cancellationToken)
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
}
