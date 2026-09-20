using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MotoHub.Infrastructure.Storage;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class LocalProductImageStorageTests
{
    [Fact]
    public async Task Saves_complete_content_with_generated_key_and_public_url()
    {
        var root = CreateTempDirectory();
        try
        {
            var storage = CreateStorage(root);
            var productId = Guid.NewGuid();
            var content = "image bytes"u8.ToArray();
            var result = await storage.SaveAsync(productId, new MemoryStream(content), ".jpg", default);

            Assert.Contains($"products/{productId:N}/", result.StorageKey);
            Assert.EndsWith(".jpg", result.StorageKey);
            Assert.Contains("/media/product-images/products/", result.Url);
            Assert.DoesNotContain(root, result.Url, StringComparison.OrdinalIgnoreCase);
            var filePath = Path.Combine(root, "storage/product-images", result.StorageKey.Replace('/', Path.DirectorySeparatorChar));
            Assert.True(File.Exists(filePath));
            Assert.Equal(content, await File.ReadAllBytesAsync(filePath));
        }
        finally { Directory.Delete(root, true); }
    }

    [Fact]
    public async Task Delete_removes_existing_file_and_is_idempotent_for_missing_file()
    {
        var root = CreateTempDirectory();
        try
        {
            var storage = CreateStorage(root);
            var result = await storage.SaveAsync(Guid.NewGuid(), new MemoryStream([1, 2, 3]), ".png", default);
            var filePath = Path.Combine(root, "storage/product-images", result.StorageKey.Replace('/', Path.DirectorySeparatorChar));
            await storage.DeleteAsync(result.StorageKey, default);
            Assert.False(File.Exists(filePath));
            await storage.DeleteAsync(result.StorageKey, default);
        }
        finally { Directory.Delete(root, true); }
    }

    [Theory]
    [InlineData("../outside.jpg")]
    [InlineData("../../outside.jpg")]
    [InlineData("..\\..\\outside.jpg")]
    [InlineData("C:\\outside.jpg")]
    public async Task Delete_rejects_path_traversal(string storageKey)
    {
        var root = CreateTempDirectory();
        try
        {
            var storage = CreateStorage(root);
            await Assert.ThrowsAsync<InvalidOperationException>(() => storage.DeleteAsync(storageKey, default));
        }
        finally { Directory.Delete(root, true); }
    }

    private static LocalProductImageStorage CreateStorage(string root)
        => new(new TestHostEnvironment(root), Options.Create(new ProductImageStorageOptions()), NullLogger<LocalProductImageStorage>.Instance);

    private static string CreateTempDirectory()
    {
        var path = Path.Combine(Path.GetTempPath(), "motohub-tests", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(path);
        return path;
    }

    private sealed class TestHostEnvironment(string contentRootPath) : Microsoft.Extensions.Hosting.IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Testing";
        public string ApplicationName { get; set; } = "MotoHub.Tests";
        public string ContentRootPath { get; set; } = contentRootPath;
        public Microsoft.Extensions.FileProviders.IFileProvider ContentRootFileProvider { get; set; } = new Microsoft.Extensions.FileProviders.NullFileProvider();
    }
}