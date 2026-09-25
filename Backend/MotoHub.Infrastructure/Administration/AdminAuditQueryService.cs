using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Application.Admin;
using MotoHub.Application.Errors;
using MotoHub.Infrastructure.Authentication;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Administration;

public sealed class AdminAuditQueryService(
    MotoHubDbContext dbContext,
    IAdminOperationalAccessService adminOperationalAccessService) : IAdminAuditQueryService
{
    private const int MaxPageSize = 50;

    public async Task<AdminPagedResponse<AdminAuditLogListItemDto>> ListAsync(
        Guid actorUserId,
        AdminAuditLogQuery query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        await adminOperationalAccessService.EnsureOperationalAdminAsync(actorUserId, cancellationToken);

        var action = NormalizeFilter(query.Action, nameof(query.Action));
        var entityType = NormalizeFilter(query.EntityType, nameof(query.EntityType));
        var correlationId = NormalizeFilter(query.CorrelationId, nameof(query.CorrelationId));
        var from = query.From?.ToUniversalTime();
        var to = query.To?.ToUniversalTime();

        var auditLogs = dbContext.AuditLogs
            .AsNoTracking()
            .AsQueryable();

        if (query.ActorUserId.HasValue)
            auditLogs = auditLogs.Where(x => x.ActorUserId == query.ActorUserId.Value);
        if (!string.IsNullOrWhiteSpace(action))
            auditLogs = auditLogs.Where(x => x.Action == action);
        if (!string.IsNullOrWhiteSpace(entityType))
            auditLogs = auditLogs.Where(x => x.EntityType == entityType);
        if (query.EntityId.HasValue)
            auditLogs = auditLogs.Where(x => x.EntityId == query.EntityId.Value);
        if (from.HasValue)
            auditLogs = auditLogs.Where(x => x.CreatedAt >= from.Value);
        if (to.HasValue)
            auditLogs = auditLogs.Where(x => x.CreatedAt < to.Value);
        if (!string.IsNullOrWhiteSpace(correlationId))
            auditLogs = auditLogs.Where(x => x.CorrelationId == correlationId);

        var totalCount = await auditLogs.CountAsync(cancellationToken);
        var pageSize = query.PageSize;
        var rows = await (
            from audit in auditLogs
            join domainActor in dbContext.Users.IgnoreQueryFilters().AsNoTracking()
                on audit.ActorUserId equals (Guid?)domainActor.Id into domainActors
            from domainActor in domainActors.DefaultIfEmpty()
            join identityActor in dbContext.Set<MotoHubIdentityUser>().AsNoTracking()
                on audit.ActorUserId equals (Guid?)identityActor.Id into identityActors
            from identityActor in identityActors.DefaultIfEmpty()
            orderby audit.CreatedAt descending, audit.Id descending
            select new AdminAuditLogListItemDto(
                audit.Id,
                audit.ActorUserId,
                identityActor == null
                    ? domainActor == null ? null : domainActor.UserName ?? domainActor.Email
                    : identityActor.UserName ?? identityActor.Email
                        ?? (domainActor == null ? null : domainActor.UserName ?? domainActor.Email),
                audit.Action,
                audit.EntityType,
                audit.EntityId,
                audit.CorrelationId,
                audit.CreatedAt))
            .Skip((query.Page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);

        var totalPages = totalCount == 0
            ? 0
            : (int)Math.Ceiling(totalCount / (double)pageSize);
        return new AdminPagedResponse<AdminAuditLogListItemDto>(
            rows,
            query.Page,
            pageSize,
            totalCount,
            totalPages);
    }

    private static void ValidateQuery(AdminAuditLogQuery query)
    {
        if (query is null)
            throw new ValidationException("La consulta de auditoría es obligatoria.");
        if (query.Page < 1)
            throw new ValidationException("Page debe ser mayor o igual que uno.");
        if (query.PageSize < 1 || query.PageSize > MaxPageSize)
            throw new ValidationException($"PageSize debe estar entre uno y {MaxPageSize}.");
        if (query.From.HasValue && query.To.HasValue && query.From.Value > query.To.Value)
            throw new ValidationException("From no puede ser posterior a To.");
    }

    private static string? NormalizeFilter(string? value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value))
            return null;
        var normalized = value.Trim();
        if (normalized.Length > 100)
            throw new ValidationException($"{parameterName} no puede superar 100 caracteres.");
        return normalized;
    }
}
