using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/products/{productId:guid}/images")]
public sealed class ProductImagesController(IProductImageService imageService) : CurrentUserControllerBase
{
    [HttpPost]
    [RequestSizeLimit(5 * 1024 * 1024 + 64 * 1024)]
    public async Task<IActionResult> Upload(Guid productId, IFormFile? file, CancellationToken cancellationToken)
    {
        if (file is null) throw new MotoHub.Application.Errors.ValidationException("El archivo de imagen es obligatorio.");
        await using var content = new MemoryStream();
        await file.CopyToAsync(content, cancellationToken);
        content.Position = 0;
        var image = await imageService.UploadAsync(
            CurrentUserId(),
            productId,
            new UploadProductImageRequest(content, file.FileName, file.ContentType, file.Length),
            cancellationToken);
        return Ok(image);
    }

    [HttpDelete("{imageId:guid}")]
    public async Task<IActionResult> Delete(Guid productId, Guid imageId, CancellationToken cancellationToken)
    {
        await imageService.DeleteAsync(CurrentUserId(), productId, imageId, cancellationToken);
        return NoContent();
    }

    [HttpPut("{imageId:guid}/primary")]
    public Task<ProductImageResponseDto> SetPrimary(Guid productId, Guid imageId, CancellationToken cancellationToken)
        => imageService.SetPrimaryAsync(CurrentUserId(), productId, imageId, cancellationToken);
}