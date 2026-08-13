using Microsoft.EntityFrameworkCore;

namespace MotoHub.Infrastructure.Persistence;

internal static class MotoHubModelConfiguration
{
    public static void Configure(ModelBuilder builder)
    {
        foreach (var module in ModelConfigurationModules.All)
        {
            module.Configure(builder);
        }
    }
}
