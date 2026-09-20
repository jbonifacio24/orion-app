namespace MotoHub.Application.Storage;

public sealed record StoredProductImage(string StorageKey, string Url);

public interface IProductImageStorage
{
    Task<StoredProductImage> SaveAsync(Guid productId, Stream content, string extension, CancellationToken cancellationToken);
    Task DeleteAsync(string storageKey, CancellationToken cancellationToken);
}