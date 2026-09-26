using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Authentication;

public sealed class OperationalUserAccessService(MotoHubDbContext dbContext) : IOperationalUserAccessService
{
    public async Task<bool> IsOperationalAsync(Guid userId, CancellationToken cancellationToken)
    {
        var identityExists = await dbContext.Set<MotoHubIdentityUser>()
            .AsNoTracking()
            .AnyAsync(user => user.Id == userId, cancellationToken);
        if (!identityExists)
        {
            return false;
        }

        var profile = await dbContext.Users
            .IgnoreQueryFilters()
            .AsNoTracking()
            .SingleOrDefaultAsync(user => user.Id == userId, cancellationToken);

        return profile is { IsActive: true, IsDeleted: false };
    }
}