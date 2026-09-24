namespace MotoHub.Infrastructure.Authentication;

public sealed class AuthOptions
{
    public bool RequireConfirmedEmail { get; set; } = true;
    public string DefaultRole { get; set; } = "User";
    public string DevelopmentUserName { get; set; } = "demo";
    public string DevelopmentUserEmail { get; set; } = "demo@motohub.local";
    public string DevelopmentUserPassword { get; set; } = "MotoHubDemo2026";
}