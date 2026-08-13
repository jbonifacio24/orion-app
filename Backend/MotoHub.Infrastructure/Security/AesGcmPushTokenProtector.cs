using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;
using MotoHub.Application;

namespace MotoHub.Infrastructure.Security;

public sealed class AesGcmPushTokenProtector(IOptions<PushTokenEncryptionOptions> options) : IPushTokenProtector
{
    private const int NonceSize = 12;
    private const int TagSize = 16;

    public string Protect(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        var key = GetKey();
        var nonce = RandomNumberGenerator.GetBytes(NonceSize);
        var plaintext = Encoding.UTF8.GetBytes(token);
        var ciphertext = new byte[plaintext.Length];
        var tag = new byte[TagSize];

        using var aes = new AesGcm(key, TagSize);
        aes.Encrypt(nonce, plaintext, ciphertext, tag);

        var result = new byte[nonce.Length + tag.Length + ciphertext.Length];
        Buffer.BlockCopy(nonce, 0, result, 0, nonce.Length);
        Buffer.BlockCopy(tag, 0, result, nonce.Length, tag.Length);
        Buffer.BlockCopy(ciphertext, 0, result, nonce.Length + tag.Length, ciphertext.Length);
        return Convert.ToBase64String(result);
    }

    public string Unprotect(string protectedToken)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(protectedToken);
        var payload = Convert.FromBase64String(protectedToken);
        if (payload.Length < NonceSize + TagSize)
        {
            throw new CryptographicException("The protected push token payload is invalid.");
        }

        var key = GetKey();
        var nonce = payload[..NonceSize];
        var tag = payload[NonceSize..(NonceSize + TagSize)];
        var ciphertext = payload[(NonceSize + TagSize)..];
        var plaintext = new byte[ciphertext.Length];

        using var aes = new AesGcm(key, TagSize);
        aes.Decrypt(nonce, ciphertext, tag, plaintext);
        return Encoding.UTF8.GetString(plaintext);
    }

    private byte[] GetKey()
    {
        var configuredKey = options.Value.PushTokenEncryptionKey;
        if (string.IsNullOrWhiteSpace(configuredKey))
        {
            throw new InvalidOperationException("Security:PushTokenEncryptionKey must be configured outside source control.");
        }

        try
        {
            var key = Convert.FromBase64String(configuredKey);
            return key.Length is 16 or 24 or 32
                ? key
                : throw new InvalidOperationException("Push token encryption key must be 128, 192 or 256 bits.");
        }
        catch (FormatException exception)
        {
            throw new InvalidOperationException("Push token encryption key must be a base64 value.", exception);
        }
    }
}