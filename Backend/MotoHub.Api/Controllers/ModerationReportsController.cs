using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Moderation;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/reports")]
public sealed class ModerationReportsController(IModerationReportService moderationReportService) : CurrentUserControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Create(CreateModerationReportRequest request, CancellationToken cancellationToken)
    {
        var response = await moderationReportService.CreateAsync(CurrentUserId(), request, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, response);
    }
}