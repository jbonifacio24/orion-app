namespace MotoHub.Application.Storage;

public sealed record StoredMotorcycleImage(string StorageKey, string Url);

public interface IMotorcycleImageStorage
{
    Task<StoredMotorcycleImage> SaveAsync(Guid motorcycleId, Stream content, CancellationToken cancellationToken);
    Task DeleteAsync(string storageKey, CancellationToken cancellationToken);
}
