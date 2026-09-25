using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using MotoHub.Application;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Auditing;

public sealed class AuditService(
    MotoHubDbContext dbContext,
    IHttpContextAccessor httpContextAccessor) : IAuditService
{
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

        if (AuditPayloadSecurity.ContainsSensitivePayload(entry.OldValuesJson) ||
            AuditPayloadSecurity.ContainsSensitivePayload(entry.NewValuesJson))
            throw new InvalidOperationException("Audit payload cannot contain credentials, tokens or secrets.");
    }

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