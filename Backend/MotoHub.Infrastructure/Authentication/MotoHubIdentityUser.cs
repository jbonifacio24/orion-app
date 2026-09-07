using Microsoft.AspNetCore.Identity;

namespace MotoHub.Infrastructure.Authentication;

public sealed class MotoHubIdentityUser : IdentityUser<Guid>
{
}

public sealed class MotoHubIdentityRole : IdentityRole<Guid>
{
}