using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;
using MotoHub.Application.TheftReports;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/theft-reports")]
public sealed class TheftReportsController(ITheftReportService theftReportService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<PagedResponse<TheftReportResponseDto>> Get([FromQuery] TheftReportListQueryDto query, CancellationToken cancellationToken)
        => theftReportService.GetActiveAsync(query, cancellationToken);

    [HttpGet("mine")]
    public Task<PagedResponse<TheftReportResponseDto>> GetMine([FromQuery] TheftReportListQueryDto query, CancellationToken cancellationToken)
        => theftReportService.GetMineAsync(CurrentUserId(), query, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<TheftReportResponseDto> GetById(Guid id, CancellationToken cancellationToken)
        => theftReportService.GetByIdAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost]
    public async Task<IActionResult> Create(CreateTheftReportRequestDto request, CancellationToken cancellationToken)
    {
        var report = await theftReportService.CreateAsync(CurrentUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = report.Id }, report);
    }

    [HttpPatch("{id:guid}/status")]
    public Task<TheftReportResponseDto> UpdateStatus(Guid id, UpdateTheftReportStatusRequestDto request, CancellationToken cancellationToken)
        => theftReportService.UpdateStatusAsync(CurrentUserId(), id, request, cancellationToken);
}