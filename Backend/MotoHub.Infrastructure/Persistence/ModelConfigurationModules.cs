using Microsoft.EntityFrameworkCore;

namespace MotoHub.Infrastructure.Persistence;

internal interface IModelConfigurationModule
{
    void Configure(ModelBuilder builder);
}

internal static class ModelConfigurationModules
{
    public static IReadOnlyList<IModelConfigurationModule> All { get; } =
    [
        new BaseConfigurationModule(),
        new MotorcycleConfigurationModule(),
        new MarketplaceConfigurationModule(),
        new WorkshopConfigurationModule(),
        new SafetyAndNotificationConfigurationModule(),
        new ChatConfigurationModule(),
        new CommunityAndNewsConfigurationModule(),
        new ReferralAndSubscriptionConfigurationModule(),
        new ReportConfigurationModule()
    ];
}