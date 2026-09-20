namespace MotoHub.Application.Marketplace;

public sealed record UploadProductImageRequest(
    Stream Content,
    string FileName,
    string? ContentType,
    long Length);