namespace MotoHub.Application.Marketplace;

public interface IProductImageService
{
    Task<ProductImageResponseDto> UploadAsync(Guid userId, Guid productId, UploadProductImageRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid productId, Guid imageId, CancellationToken cancellationToken);
    Task<ProductImageResponseDto> SetPrimaryAsync(Guid userId, Guid productId, Guid imageId, CancellationToken cancellationToken);
}