using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace MotoHub.Infrastructure.Marketplace;

public static class MarketplaceConflictClassifier
{
    public static bool IsProductFavoriteUniqueConflict(DbUpdateException exception)
    {
        for (var current = exception.InnerException; current is not null; current = current.InnerException)
        {
            if (current is SqlException sqlException && IsProductFavoriteUniqueConflict(sqlException.Number, sqlException.Message)) return true;
        }
        return false;
    }

    public static bool IsProductFavoriteUniqueConflict(int sqlErrorNumber, string message)
        => (sqlErrorNumber is 2601 or 2627) && message.Contains("ProductFavorites", StringComparison.OrdinalIgnoreCase);
}
