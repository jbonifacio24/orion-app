namespace MotoHub.Infrastructure.Authentication;

public sealed class AuthOptions
{
    public bool RequireConfirmedEmail { get; set; } = true;
    public string DefaultRole { get; set; } = "User";
}