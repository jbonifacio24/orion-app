using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
[Route("api/admin")]
public sealed class AdminAccessController : ControllerBase
{
    [HttpGet("access")]
    public IActionResult GetAccess() => Ok(new { authorized = true });
}