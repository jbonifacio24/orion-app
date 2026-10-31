using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace MotoHub.Infrastructure.Marketplace;

public static class MarketplaceConflictClassifier
{
    public static bool IsProductFavoriteUniqueConflict(DbUpdateException exception)
    {
        for (var current = exception.InnerException; current is not null; current = current.InnerException)
        {
            if (current is PostgresException postgresException && IsProductFavoriteUniqueConflict(postgresException.SqlState, postgresException.ConstraintName)) return true;
        }
        return false;
    }

    public static bool IsProductFavoriteUniqueConflict(string sqlState, string? constraintName)
        => sqlState == PostgresErrorCodes.UniqueViolation && constraintName?.Contains("ProductFavorites", StringComparison.OrdinalIgnoreCase) == true;
}
