using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;

namespace MotoHub.Api.Controllers;

public abstract class CurrentUserControllerBase : ControllerBase
{
    protected Guid CurrentUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new AuthenticationException("The access token subject is invalid.", 401);
    }
}
