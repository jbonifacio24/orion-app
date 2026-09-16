namespace MotoHub.Application.Marketplace;

public interface IFavoriteService
{
    Task<IReadOnlyCollection<ProductResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken);
    Task AddAsync(Guid userId, Guid productId, CancellationToken cancellationToken);
    Task RemoveAsync(Guid userId, Guid productId, CancellationToken cancellationToken);
}
