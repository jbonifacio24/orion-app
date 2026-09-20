using Microsoft.Extensions.Options;
using MotoHub.Application.Errors;
using MotoHub.Infrastructure.Storage;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class ImageFileValidatorTests
{
    private readonly ImageFileValidator validator = new(Options.Create(new ProductImageStorageOptions()));

    [Fact]
    public async Task Accepts_jpeg_and_resets_stream()
    {
        using var stream = new MemoryStream([0xFF, 0xD8, 0xFF, 0x00]);
        stream.Position = stream.Length;

        var extension = await validator.ValidateAsync(stream, "photo.jpg", "image/jpeg", stream.Length, default);

        Assert.Equal(".jpg", extension);
        Assert.Equal(0, stream.Position);
        Assert.Equal(0xFF, stream.ReadByte());
    }

    [Fact]
    public async Task Accepts_png_and_webp_signatures()
    {
        using var png = new MemoryStream([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        using var webp = new MemoryStream("RIFFxxxxWEBP"u8.ToArray());

        Assert.Equal(".png", await validator.ValidateAsync(png, "photo.png", "image/png", png.Length, default));
        Assert.Equal(".webp", await validator.ValidateAsync(webp, "photo.webp", "image/webp", webp.Length, default));
    }

    [Theory]
    [InlineData("photo.jpg", "image/png", "signature")]
    [InlineData("photo.gif", "image/gif", "format")]
    [InlineData("photo.jpg", "image/jpeg", "signature")]
    [InlineData("photo.png", "image/png", "signature")]
    [InlineData("photo.webp", "image/webp", "signature")]
    public async Task Rejects_invalid_type_extension_or_signature(string fileName, string contentType, string kind)
    {
        var content = kind == "format"
            ? [0x47, 0x49, 0x46, 0x38]
            : kind == "signature" && fileName.EndsWith(".jpg")
                ? [0x00, 0x00, 0x00]
                : kind == "signature" && fileName.EndsWith(".png")
                    ? [0x00, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
                    : "RIFFxxxxNOPE"u8.ToArray();

        await Assert.ThrowsAsync<ValidationException>(() => validator.ValidateAsync(new MemoryStream(content), fileName, contentType, content.Length, default));
    }

    [Fact]
    public async Task Rejects_empty_svg_and_oversized_content()
    {
        await Assert.ThrowsAsync<ValidationException>(() => validator.ValidateAsync(new MemoryStream(), "empty.jpg", "image/jpeg", 0, default));
        var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>"u8.ToArray();
        await Assert.ThrowsAsync<ValidationException>(() => validator.ValidateAsync(new MemoryStream(svg), "image.svg", "image/svg+xml", svg.Length, default));
        var oversized = new MemoryStream(new byte[5 * 1024 * 1024 + 1]);
        await Assert.ThrowsAsync<ValidationException>(() => validator.ValidateAsync(oversized, "large.jpg", "image/jpeg", oversized.Length, default));
    }
}