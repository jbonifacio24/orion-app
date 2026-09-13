using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Motorcycles;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/motorcycles")]
public sealed class MotorcyclesController(IMotorcycleService motorcycleService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<IReadOnlyCollection<MotorcycleResponseDto>> GetMine(CancellationToken cancellationToken)
        => motorcycleService.GetMineAsync(CurrentUserId(), cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<MotorcycleResponseDto> GetById(Guid id, CancellationToken cancellationToken)
        => motorcycleService.GetByIdAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost]
    public Task<MotorcycleResponseDto> Create(CreateMotorcycleRequestDto request, CancellationToken cancellationToken)
        => motorcycleService.CreateAsync(CurrentUserId(), request, cancellationToken);

    [HttpPut("{id:guid}")]
    public Task<MotorcycleResponseDto> Update(Guid id, UpdateMotorcycleRequestDto request, CancellationToken cancellationToken)
        => motorcycleService.UpdateAsync(CurrentUserId(), id, request, cancellationToken);

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await motorcycleService.DeleteAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }
}
