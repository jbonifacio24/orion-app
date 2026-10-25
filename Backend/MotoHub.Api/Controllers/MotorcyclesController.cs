using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application;
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

    [HttpDelete("{id:guid}/admin")]
    [Authorize(Policy = AdminSecurity.AdminAccessPolicy)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> DeleteAsAdmin(Guid id, CancellationToken cancellationToken)
    {
        await motorcycleService.DeleteAsAdminAsync(id, cancellationToken);
        return NoContent();
    }

    [HttpPost("{id:guid}/images")]
    [Consumes("multipart/form-data")]
    public async Task<MotorcycleImageResponseDto> UploadImage(Guid id, IFormFile file, [FromServices] IMotorcycleImageService imageService, CancellationToken cancellationToken)
    {
        await using var content = file.OpenReadStream();
        return await imageService.UploadAsync(CurrentUserId(), id, new UploadMotorcycleImageRequest(content, file.FileName, file.ContentType, file.Length), cancellationToken);
    }

    [HttpDelete("{id:guid}/images/{imageId:guid}")]
    public async Task<IActionResult> DeleteImage(Guid id, Guid imageId, [FromServices] IMotorcycleImageService imageService, CancellationToken cancellationToken)
    {
        await imageService.DeleteAsync(CurrentUserId(), id, imageId, cancellationToken);
        return NoContent();
    }
}
