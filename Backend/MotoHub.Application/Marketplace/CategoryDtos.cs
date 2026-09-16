namespace MotoHub.Application.Marketplace;

public interface ICategoryService
{
    Task<IReadOnlyCollection<ProductCategoryResponseDto>> GetActiveAsync(CancellationToken cancellationToken);
}
