using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Workshops;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/workshops")]
public sealed class WorkshopsController(IWorkshopService workshopService) : ControllerBase
{
    [HttpGet]
    public Task<PagedResponse<WorkshopListItemDto>> Get([FromQuery] WorkshopListQueryDto query, CancellationToken cancellationToken)
        => workshopService.GetWorkshopsAsync(query, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<WorkshopDetailResponseDto> GetById(Guid id, CancellationToken cancellationToken)
        => workshopService.GetWorkshopByIdAsync(id, cancellationToken);
}