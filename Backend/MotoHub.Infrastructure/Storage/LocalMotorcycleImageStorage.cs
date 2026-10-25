using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MotoHub.Application.Storage;

namespace MotoHub.Infrastructure.Storage;

public sealed class LocalMotorcycleImageStorage(
    IHostEnvironment environment,
    IOptions<ProductImageStorageOptions> options,
    ILogger<LocalMotorcycleImageStorage> logger) : IMotorcycleImageStorage
{
    private string RootPath => Path.GetFullPath(Path.Combine(environment.ContentRootPath, options.Value.StorageRoot));

    public async Task<StoredMotorcycleImage> SaveAsync(Guid motorcycleId, Stream content, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine("motorcycles", motorcycleId.ToString("N"));
        var directory = Path.Combine(RootPath, relativeDirectory);
        Directory.CreateDirectory(directory);
        var fileName = $"{Guid.NewGuid():N}.jpg";
        var fullPath = Path.Combine(directory, fileName);
        await using (var target = new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        {
            await content.CopyToAsync(target, cancellationToken);
        }

        var storageKey = $"motorcycles/{motorcycleId:N}/{fileName}";
        var url = $"{options.Value.PublicBasePath.TrimEnd('/')}/motorcycles/{motorcycleId:N}/{fileName}";
        logger.LogDebug("Stored motorcycle image {StorageKey}.", storageKey);
        return new StoredMotorcycleImage(storageKey, url);
    }

    public Task DeleteAsync(string storageKey, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var normalized = storageKey.Replace('/', Path.DirectorySeparatorChar);
        var root = RootPath.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        var fullPath = Path.GetFullPath(Path.Combine(RootPath, normalized));
        if (!fullPath.StartsWith(root, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("El storage key no es válido.");
        if (File.Exists(fullPath)) File.Delete(fullPath);
        return Task.CompletedTask;
    }
}
