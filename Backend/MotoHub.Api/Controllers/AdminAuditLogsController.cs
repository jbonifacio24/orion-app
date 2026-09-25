using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;
using MotoHub.Application.Admin;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
[Route("api/admin/audit-logs")]
public sealed class AdminAuditLogsController(IAdminAuditQueryService adminAuditQueryService) : ControllerBase
{
    [HttpGet]
    public Task<AdminPagedResponse<AdminAuditLogListItemDto>> List(
        [FromQuery] AdminAuditLogQuery query,
        CancellationToken cancellationToken)
        => adminAuditQueryService.ListAsync(
            GetActorUserId(),
            query,
            cancellationToken);

    private Guid GetActorUserId()
    {
        var value = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? User.FindFirstValue("sub");
        if (!Guid.TryParse(value, out var actorUserId))
            throw new AuthenticationException("El sujeto autenticado no es válido.", 401);
        return actorUserId;
    }
}
