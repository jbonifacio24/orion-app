using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Http;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Auditing;

public sealed class AuditService(
    MotoHubDbContext dbContext,
    IHttpContextAccessor httpContextAccessor) : IAuditService
{
    private static readonly HashSet<string> ForbiddenPropertyNames =
    [
        "password", "passwd", "pwd",
        "token", "accesstoken", "refreshtoken", "idtoken",
        "authorization", "authheader", "authorizationheader", "bearer", "bearertoken",
        "apikey", "credential", "credentials", "jwt",
        "privatekey", "connectionstring",
        "secret", "clientsecret"
    ];

    private static readonly Regex UnstructuredPropertyPattern = new(
        @"(?<![\p{L}\p{N}_-])(?<name>[\p{L}][\p{L}\p{N}_-]*)(?=\s*[:=])",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public async Task WriteAsync(AuditEntry entry, CancellationToken cancellationToken)
    {
        Validate(entry);
        var httpContext = httpContextAccessor.HttpContext;
        var actorUserId = GetActorUserId(httpContext);
        var correlationId = httpContext?.Request.Headers["X-Correlation-ID"].FirstOrDefault()
            ?? httpContext?.TraceIdentifier;

        dbContext.AuditLogs.Add(new AuditLog
        {
            ActorUserId = actorUserId,
            Action = entry.Action,
            EntityType = entry.EntityType,
            EntityId = entry.EntityId,
            OldValuesJson = entry.OldValuesJson,
            NewValuesJson = entry.NewValuesJson,
            IpAddress = httpContext?.Connection.RemoteIpAddress?.ToString(),
            UserAgent = httpContext?.Request.Headers.UserAgent.FirstOrDefault(),
            CorrelationId = TrimTo(correlationId, 100)
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static void Validate(AuditEntry entry)
    {
        if (string.IsNullOrWhiteSpace(entry.Action) || entry.Action.Length > 100)
            throw new ArgumentException("Audit action is required and cannot exceed 100 characters.", nameof(entry));
        if (string.IsNullOrWhiteSpace(entry.EntityType) || entry.EntityType.Length > 100)
            throw new ArgumentException("Audit entity type is required and cannot exceed 100 characters.", nameof(entry));

        if (ContainsForbiddenPayload(entry.OldValuesJson) || ContainsForbiddenPayload(entry.NewValuesJson))
            throw new InvalidOperationException("Audit payload cannot contain credentials, tokens or secrets.");
    }

    private static bool ContainsForbiddenPayload(string? payload)
    {
        if (string.IsNullOrWhiteSpace(payload)) return false;

        try
        {
            using var document = JsonDocument.Parse(payload);
            return ContainsForbiddenProperty(document.RootElement);
        }
        catch (JsonException)
        {
            return UnstructuredPropertyPattern.Matches(payload)
                .Any(match => ForbiddenPropertyNames.Contains(NormalizePropertyName(match.Groups["name"].Value)));
        }
    }

    private static bool ContainsForbiddenProperty(JsonElement element)
    {
        switch (element.ValueKind)
        {
            case JsonValueKind.Object:
                foreach (var property in element.EnumerateObject())
                {
                    if (ForbiddenPropertyNames.Contains(NormalizePropertyName(property.Name)) ||
                        ContainsForbiddenProperty(property.Value))
                    {
                        return true;
                    }
                }

                return false;

            case JsonValueKind.Array:
                return element.EnumerateArray().Any(ContainsForbiddenProperty);

            default:
                return false;
        }
    }

    private static string NormalizePropertyName(string propertyName)
        => string.Concat(propertyName.Where(char.IsLetterOrDigit)).ToLowerInvariant();

    private static Guid? GetActorUserId(HttpContext? context)
    {
        var value = context?.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context?.User.FindFirstValue(JwtRegisteredClaimNames.Sub)
            ?? context?.User.FindFirstValue("sub");
        return Guid.TryParse(value, out var userId) ? userId : null;
    }

    private static string? TrimTo(string? value, int maxLength)
        => value is null || value.Length <= maxLength ? value : value[..maxLength];
}