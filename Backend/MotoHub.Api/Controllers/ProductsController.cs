using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/products")]
public sealed class ProductsController(IProductService productService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<PagedResponse<ProductResponseDto>> Get(ProductListQueryDto query, CancellationToken cancellationToken)
        => productService.GetActiveAsync(query, CurrentUserId(), cancellationToken);

    [HttpGet("mine")]
    public Task<PagedResponse<ProductResponseDto>> GetMine(ProductListQueryDto query, CancellationToken cancellationToken)
        => productService.GetMineAsync(CurrentUserId(), query, cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<ProductDetailResponseDto> GetById(Guid id, CancellationToken cancellationToken)
        => productService.GetByIdAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost]
    public async Task<IActionResult> Create(CreateProductRequestDto request, CancellationToken cancellationToken)
    {
        var product = await productService.CreateAsync(CurrentUserId(), request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }

    [HttpPut("{id:guid}")]
    public Task<ProductResponseDto> Update(Guid id, UpdateProductRequestDto request, CancellationToken cancellationToken)
        => productService.UpdateAsync(CurrentUserId(), id, request, cancellationToken);

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken cancellationToken)
    {
        await productService.DeleteAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }
}
