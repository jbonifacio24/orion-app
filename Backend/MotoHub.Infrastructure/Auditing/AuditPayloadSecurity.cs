using System.Text.Json;
using System.Text.RegularExpressions;

namespace MotoHub.Infrastructure.Auditing;

internal static class AuditPayloadSecurity
{
    internal const string RedactedMarker = "[REDACTED]";

    private static readonly HashSet<string> SensitivePropertyNames =
    [
        "password", "passwd", "pwd", "passwordhash",
        "token", "accesstoken", "refreshtoken", "refreshtokenhash", "idtoken",
        "authorization", "authheader", "authorizationheader",
        "apikey", "credential", "credentials", "bearer", "bearertoken", "jwt",
        "privatekey", "connectionstring", "secret", "clientsecret", "securitystamp"
    ];

    private static readonly Regex UnstructuredPropertyPattern = new(
        @"(?<![\p{L}\p{N}_-])(?<name>[\p{L}][\p{L}\p{N}_-]*)(?=\s*[:=])",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    internal static bool IsSensitivePropertyName(string propertyName)
        => SensitivePropertyNames.Contains(NormalizePropertyName(propertyName));

    internal static bool ContainsSensitivePayload(string? payload)
    {
        if (string.IsNullOrWhiteSpace(payload))
            return false;

        try
        {
            using var document = JsonDocument.Parse(payload);
            return ContainsSensitiveProperty(document.RootElement);
        }
        catch (JsonException)
        {
            return UnstructuredPropertyPattern.Matches(payload)
                .Any(match => IsSensitivePropertyName(match.Groups["name"].Value));
        }
    }

    internal static string NormalizePropertyName(string propertyName)
        => string.Concat(propertyName.Where(char.IsLetterOrDigit)).ToLowerInvariant();

    private static bool ContainsSensitiveProperty(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                if (IsSensitivePropertyName(property.Name) || ContainsSensitiveProperty(property.Value))
                    return true;
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            return element.EnumerateArray().Any(ContainsSensitiveProperty);
        }

        return false;
    }
}
