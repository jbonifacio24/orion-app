using System.Text.Json;
using System.Text.Json.Nodes;
using MotoHub.Application.Admin;

namespace MotoHub.Infrastructure.Auditing;

public sealed class AuditPayloadSanitizer
{
    public AuditPayloadDto? Sanitize(string? payload)
    {
        if (payload is null)
            return null;
        if (string.IsNullOrWhiteSpace(payload))
            return new AuditPayloadDto(AuditPayloadStatus.Unavailable, null);

        try
        {
            using var document = JsonDocument.Parse(payload);
            var wasRedacted = false;
            var sanitized = SanitizeElement(document.RootElement, ref wasRedacted, redactUnkeyedStrings: true);
            var json = sanitized?.ToJsonString() ?? "null";
            using var sanitizedDocument = JsonDocument.Parse(json);
            return new AuditPayloadDto(
                wasRedacted ? AuditPayloadStatus.Redacted : AuditPayloadStatus.Available,
                sanitizedDocument.RootElement.Clone());
        }
        catch (JsonException)
        {
            return new AuditPayloadDto(AuditPayloadStatus.Unavailable, null);
        }
    }

    private static JsonNode? SanitizeElement(
        JsonElement element,
        ref bool wasRedacted,
        bool redactUnkeyedStrings)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
            {
                var result = new JsonObject();
                foreach (var property in element.EnumerateObject())
                {
                    if (AuditPayloadSecurity.IsSensitivePropertyName(property.Name))
                    {
                        result[property.Name] = AuditPayloadSecurity.RedactedMarker;
                        wasRedacted = true;
                    }
                    else
                    {
                        result[property.Name] = SanitizeElement(
                            property.Value,
                            ref wasRedacted,
                            redactUnkeyedStrings: false);
                    }
                }

                return result;
            }
            case JsonValueKind.Array:
            {
                var result = new JsonArray();
                foreach (var item in element.EnumerateArray())
                    result.Add(SanitizeElement(item, ref wasRedacted, redactUnkeyedStrings: true));
                return result;
            }
            case JsonValueKind.String:
                if (redactUnkeyedStrings)
                {
                    wasRedacted = true;
                    return AuditPayloadSecurity.RedactedMarker;
                }

                return element.GetString();
            case JsonValueKind.Number:
            case JsonValueKind.True:
            case JsonValueKind.False:
                return JsonNode.Parse(element.GetRawText());
            case JsonValueKind.Null:
                return null;
            default:
                return null;
        }
    }
}
