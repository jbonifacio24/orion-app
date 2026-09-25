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
}
