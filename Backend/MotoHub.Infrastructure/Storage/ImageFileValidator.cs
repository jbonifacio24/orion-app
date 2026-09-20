using MotoHub.Application.Errors;
using Microsoft.Extensions.Options;

namespace MotoHub.Infrastructure.Storage;

public sealed class ImageFileValidator(IOptions<ProductImageStorageOptions> options)
{
    private static readonly IReadOnlyDictionary<string, string> AllowedTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp"
    };

    public async Task<string> ValidateAsync(Stream content, string fileName, string? contentType, long length, CancellationToken cancellationToken)
    {
        var extension = Path.GetExtension(fileName).ToLowerInvariant();
        if (length <= 0) throw new ValidationException("El archivo de imagen está vacío.");
        if (length > options.Value.MaxFileSizeBytes) throw new ValidationException("La imagen supera el tamaño máximo permitido.");
        if (!AllowedTypes.TryGetValue(extension, out var expectedType) || !string.Equals(expectedType, contentType, StringComparison.OrdinalIgnoreCase))
            throw new ValidationException("El formato de imagen no está permitido.");

        if (!content.CanSeek) throw new ValidationException("No se pudo validar el archivo de imagen.");
        content.Position = 0;
        var header = new byte[12];
        var read = await content.ReadAsync(header.AsMemory(), cancellationToken);
        content.Position = 0;
        if (!HasSignature(header, read, expectedType)) throw new ValidationException("La firma del archivo no coincide con su formato.");
        return extension == ".jpeg" ? ".jpg" : extension;
    }

    private static bool HasSignature(byte[] header, int length, string contentType)
        => contentType switch
        {
            "image/jpeg" => length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
            "image/png" => length >= 8 && header.AsSpan(0, 8).SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            "image/webp" => length >= 12 && header.AsSpan(0, 4).SequenceEqual("RIFF"u8) && header.AsSpan(8, 4).SequenceEqual("WEBP"u8),
            _ => false
        };
}