using System.Text.Json;
using MotoHub.Application.Admin;
using MotoHub.Infrastructure.Auditing;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class AuditPayloadSanitizerTests
{
    private readonly AuditPayloadSanitizer sanitizer = new();

    [Fact]
    public void Sanitize_redacts_sensitive_nested_properties_and_preserves_structure()
    {
        const string payload = """
            {
              "email": "user@test.com",
              "accessToken": "access-secret",
              "profile": {
                "displayName": "Jose",
                "client_secret": "client-secret"
              },
              "items": [
                { "name": "x", "refresh-token-hash": "refresh-secret" },
                { "safe": true }
              ]
            }
            """;

        var result = sanitizer.Sanitize(payload);
        var value = AssertPayload(result, AuditPayloadStatus.Redacted);

        Assert.Equal("user@test.com", value.GetProperty("email").GetString());
        Assert.Equal("[REDACTED]", value.GetProperty("accessToken").GetString());
        Assert.Equal("Jose", value.GetProperty("profile").GetProperty("displayName").GetString());
        Assert.Equal("[REDACTED]", value.GetProperty("profile").GetProperty("client_secret").GetString());
        Assert.Equal("[REDACTED]", value.GetProperty("items")[0].GetProperty("refresh-token-hash").GetString());
        Assert.True(value.GetProperty("items")[1].GetProperty("safe").GetBoolean());

        var serialized = JsonSerializer.Serialize(result);
        Assert.DoesNotContain("access-secret", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("client-secret", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("refresh-secret", serialized, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("passwordHash")]
    [InlineData("PasswordHash")]
    [InlineData("password_hash")]
    [InlineData("password-hash")]
    [InlineData("securityStamp")]
    [InlineData("refreshTokenHash")]
    public void Sanitize_redacts_sensitive_name_variants(string propertyName)
    {
        var result = sanitizer.Sanitize($"{{\"{propertyName}\":\"secret-value\"}}");

        var value = AssertPayload(result, AuditPayloadStatus.Redacted);
        Assert.Equal("[REDACTED]", value.GetProperty(propertyName).GetString());
        Assert.DoesNotContain("secret-value", JsonSerializer.Serialize(result), StringComparison.Ordinal);
    }

    [Fact]
    public void Sanitize_fails_closed_for_invalid_and_empty_payloads()
    {
        var invalid = sanitizer.Sanitize("token=secret-value");
        var arbitrary = sanitizer.Sanitize("historical text that is not JSON");
        var empty = sanitizer.Sanitize(" ");
        var absent = sanitizer.Sanitize(null);

        Assert.Equal(AuditPayloadStatus.Unavailable, invalid!.Status);
        Assert.Null(invalid.Value);
        Assert.Equal(AuditPayloadStatus.Unavailable, arbitrary!.Status);
        Assert.Null(arbitrary.Value);
        Assert.Equal(AuditPayloadStatus.Unavailable, empty!.Status);
        Assert.Null(empty.Value);
        Assert.Null(absent);
    }

    [Fact]
    public void Sanitize_handles_json_primitives_without_throwing()
    {
        Assert.Equal(AuditPayloadStatus.Redacted, sanitizer.Sanitize("\"historical text\"")!.Status);
        Assert.Equal(JsonValueKind.Number, AssertPayload(sanitizer.Sanitize("42"), AuditPayloadStatus.Available).ValueKind);
        Assert.Equal(JsonValueKind.True, AssertPayload(sanitizer.Sanitize("true"), AuditPayloadStatus.Available).ValueKind);
        Assert.Equal(JsonValueKind.Null, AssertPayload(sanitizer.Sanitize("null"), AuditPayloadStatus.Available).ValueKind);
    }

    [Fact]
    public void Sanitize_does_not_redact_benign_property_names()
    {
        var result = sanitizer.Sanitize("{\"tokenCount\":3,\"keyboard\":\"standard\"}");

        var value = AssertPayload(result, AuditPayloadStatus.Available);
        Assert.Equal(3, value.GetProperty("tokenCount").GetInt32());
        Assert.Equal("standard", value.GetProperty("keyboard").GetString());
    }

    private static JsonElement AssertPayload(AuditPayloadDto? payload, AuditPayloadStatus status)
    {
        Assert.NotNull(payload);
        Assert.Equal(status, payload.Status);
        Assert.True(payload.Value.HasValue);
        return payload.Value.Value;
    }
}
