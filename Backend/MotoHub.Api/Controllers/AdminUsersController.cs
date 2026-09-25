using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;
using MotoHub.Application.Admin;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
[Route("api/admin/users")]
public sealed class AdminUsersController(IAdminUserService adminUserService) : ControllerBase
{
    [HttpGet]
    public Task<AdminPagedResponse<AdminUserListItemDto>> List(
        [FromQuery] AdminUserListQuery query,
        CancellationToken cancellationToken)
        => adminUserService.ListAsync(query, cancellationToken);

    [HttpGet("{userId:guid}")]
    public Task<AdminUserDetailDto> Get(Guid userId, CancellationToken cancellationToken)
        => adminUserService.GetAsync(userId, cancellationToken);

    [HttpPatch("{userId:guid}/status")]
    public Task<AdminUserStatusResponse> UpdateStatus(
        Guid userId,
        [FromBody] AdminUserStatusRequest request,
        CancellationToken cancellationToken)
        => adminUserService.UpdateStatusAsync(
            GetActorUserId(),
            userId,
            request,
            HttpContext.Connection.RemoteIpAddress?.ToString(),
            cancellationToken);

    [HttpPost("{userId:guid}/revoke-sessions")]
    public Task<AdminSessionRevocationResponse> RevokeSessions(
        Guid userId,
        CancellationToken cancellationToken)
        => adminUserService.RevokeSessionsAsync(
            GetActorUserId(),
            userId,
            HttpContext.Connection.RemoteIpAddress?.ToString(),
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
