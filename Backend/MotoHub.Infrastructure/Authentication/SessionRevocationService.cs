using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Authentication;

public sealed class SessionRevocationService(MotoHubDbContext dbContext) : ISessionRevocationService
{
    public async Task<int> RevokeAllAsync(
        Guid userId,
        string reason,
        string? ipAddress,
        CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var tokens = await dbContext.RefreshTokens
            .Where(x => x.UserId == userId && x.RevokedAt == null)
            .ToListAsync(cancellationToken);

        foreach (var token in tokens)
        {
            token.RevokedAt = now;
            token.RevokedByIp = ipAddress;
            token.RevocationReason = reason;
        }

        if (tokens.Count > 0)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return tokens.Count;
    }
}