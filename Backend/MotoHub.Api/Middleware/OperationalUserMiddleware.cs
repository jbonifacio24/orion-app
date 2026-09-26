using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using MotoHub.Application;

namespace MotoHub.Api.Middleware;

public sealed class OperationalUserMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(
        HttpContext context,
        IOperationalUserAccessService operationalUserAccessService,
        IAdminOperationalAccessService adminOperationalAccessService)
    {
        var authorizationData = context.GetEndpoint()?.Metadata.GetOrderedMetadata<IAuthorizeData>() ?? [];
        var requiresAuthorization = authorizationData.Count > 0;
        var requiresAdminAccess = authorizationData.Any(data =>
            string.Equals(data.Policy, AdminSecurity.AdminAccessPolicy, StringComparison.Ordinal));
        if (requiresAuthorization && context.User.Identity?.IsAuthenticated == true)
        {
            var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? context.User.FindFirstValue(JwtRegisteredClaimNames.Sub)
                ?? context.User.FindFirstValue("sub");

            if (!Guid.TryParse(subject, out var userId))
            {
                context.Response.StatusCode = context.User.IsInRole(AdminSecurity.AdminRole)
                    ? StatusCodes.Status403Forbidden
                    : StatusCodes.Status401Unauthorized;
                return;
            }

            if (requiresAdminAccess)
            {
                await adminOperationalAccessService.EnsureOperationalAdminAsync(userId, context.RequestAborted);
            }
            else if (!await operationalUserAccessService.IsOperationalAsync(userId, context.RequestAborted))
            {
                context.Response.StatusCode = context.User.IsInRole(AdminSecurity.AdminRole)
                    ? StatusCodes.Status403Forbidden
                    : StatusCodes.Status401Unauthorized;
                return;
            }
        }

        await next(context);
    }
}