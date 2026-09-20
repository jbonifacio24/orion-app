namespace MotoHub.Infrastructure.Storage;

public sealed class ProductImageStorageOptions
{
    public string StorageRoot { get; set; } = "storage/product-images";
    public string PublicBasePath { get; set; } = "/media/product-images";
    public long MaxFileSizeBytes { get; set; } = 5 * 1024 * 1024;
    public int MaxImagesPerProduct { get; set; } = 10;
}