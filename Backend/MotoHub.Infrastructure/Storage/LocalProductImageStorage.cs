using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using MotoHub.Application.Storage;

namespace MotoHub.Infrastructure.Storage;

public sealed class LocalProductImageStorage(
    IHostEnvironment environment,
    IOptions<ProductImageStorageOptions> options,
    ILogger<LocalProductImageStorage> logger) : IProductImageStorage
{
    private string RootPath => Path.GetFullPath(Path.Combine(environment.ContentRootPath, options.Value.StorageRoot));

    public async Task<StoredProductImage> SaveAsync(Guid productId, Stream content, string extension, CancellationToken cancellationToken)
    {
        var relativeDirectory = Path.Combine("products", productId.ToString("N"));
        var directory = Path.Combine(RootPath, relativeDirectory);
        Directory.CreateDirectory(directory);
        var fileName = $"{Guid.NewGuid():N}{extension}";
        var fullPath = Path.Combine(directory, fileName);
        await using (var target = new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
        {
            await content.CopyToAsync(target, cancellationToken);
        }

        var storageKey = $"products/{productId:N}/{fileName}";
        var url = $"{options.Value.PublicBasePath.TrimEnd('/')}/products/{productId:N}/{fileName}";
        logger.LogDebug("Stored product image {StorageKey}.", storageKey);
        return new StoredProductImage(storageKey, url);
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