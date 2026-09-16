namespace MotoHub.Application.Marketplace;

public interface IProductService
{
    Task<PagedResponse<ProductResponseDto>> GetActiveAsync(ProductListQueryDto query, Guid userId, CancellationToken cancellationToken);
    Task<ProductDetailResponseDto> GetByIdAsync(Guid userId, Guid productId, CancellationToken cancellationToken);
    Task<PagedResponse<ProductResponseDto>> GetMineAsync(Guid userId, ProductListQueryDto query, CancellationToken cancellationToken);
    Task<ProductResponseDto> CreateAsync(Guid userId, CreateProductRequestDto request, CancellationToken cancellationToken);
    Task<ProductResponseDto> UpdateAsync(Guid userId, Guid productId, UpdateProductRequestDto request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid productId, CancellationToken cancellationToken);
}
