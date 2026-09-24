using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Notifications;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Notifications;

public sealed class NotificationService(MotoHubDbContext dbContext) : INotificationService
{
    private const int MaxPageSize = 50;
    private const int MaxMarkAllReadAttempts = 3;
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<PagedResponse<NotificationResponseDto>> GetAsync(
        Guid userId,
        NotificationListQueryDto query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var now = DateTimeOffset.UtcNow;
        var notifications = ApplyFilters(dbContext.Notifications.AsNoTracking(), userId, query, now);
        var totalCount = await notifications.CountAsync(cancellationToken);
        var items = await notifications
            .OrderByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);

        return new PagedResponse<NotificationResponseDto>(
            items.Select(ToDto).ToArray(), query.Page, query.PageSize, totalCount, totalPages);
    }

    public async Task<UnreadNotificationCountDto> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var count = await dbContext.Notifications.AsNoTracking()
            .CountAsync(x => x.RecipientUserId == userId && x.ReadAt == null &&
                             (x.ExpiresAt == null || x.ExpiresAt > now), cancellationToken);
        return new UnreadNotificationCountDto(count);
    }

    public async Task MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken)
    {
        var notification = await dbContext.Notifications
            .SingleOrDefaultAsync(x => x.Id == notificationId && x.RecipientUserId == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("La notificación no existe.");

        if (notification.ReadAt is not null)
        {
            return;
        }

        notification.ReadAt = DateTimeOffset.UtcNow;
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Read is monotonic: another request may have completed the same operation.
        }
    }

    public async Task MarkAllReadAsync(Guid userId, CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= MaxMarkAllReadAttempts; attempt++)
        {
            var now = DateTimeOffset.UtcNow;
            var notifications = await dbContext.Notifications
                .Where(x => x.RecipientUserId == userId && x.ReadAt == null &&
                            (x.ExpiresAt == null || x.ExpiresAt > now))
                .ToListAsync(cancellationToken);
            if (notifications.Count == 0)
            {
                return;
            }

            var readAt = DateTimeOffset.UtcNow;
            foreach (var notification in notifications)
            {
                notification.ReadAt = readAt;
            }

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return;
            }
            catch (DbUpdateConcurrencyException) when (attempt < MaxMarkAllReadAttempts)
            {
                foreach (var entry in dbContext.ChangeTracker.Entries<Notification>().ToArray())
                {
                    entry.State = EntityState.Detached;
                }
            }
        }

        throw new ConflictException("La operación entra en conflicto con otro proceso.");
    }

    public async Task<Guid> CreateAsync(CreateNotificationRequest request, CancellationToken cancellationToken)
    {
        var title = request.Title?.Trim() ?? string.Empty;
        var body = request.Body?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(title) || title.Length > 200)
        {
            throw new ValidationException("Title es obligatorio y debe tener como máximo 200 caracteres.");
        }

        if (string.IsNullOrWhiteSpace(body) || body.Length > 2000)
        {
            throw new ValidationException("Body es obligatorio y debe tener como máximo 2000 caracteres.");
        }

        if (!Enum.IsDefined(typeof(NotificationType), request.Type))
        {
            throw new ValidationException("Type no es válido.");
        }

        var dataJson = SerializeTarget(request.Target);
        var notification = new Notification
        {
            RecipientUserId = request.RecipientUserId,
            ActorUserId = request.ActorUserId,
            Type = request.Type,
            Title = title,
            Body = body,
            DataJson = dataJson,
            ExpiresAt = request.ExpiresAt
        };

        dbContext.Notifications.Add(notification);
        await dbContext.SaveChangesAsync(cancellationToken);
        return notification.Id;
    }

    private static IQueryable<Notification> ApplyFilters(
        IQueryable<Notification> query,
        Guid userId,
        NotificationListQueryDto options,
        DateTimeOffset now)
    {
        query = query.Where(x => x.RecipientUserId == userId &&
                                 (x.ExpiresAt == null || x.ExpiresAt > now));
        if (options.UnreadOnly)
        {
            query = query.Where(x => x.ReadAt == null);
        }

        if (options.Type.HasValue)
        {
            query = query.Where(x => x.Type == options.Type.Value);
        }

        return query;
    }

    private static void ValidateQuery(NotificationListQueryDto query)
    {
        if (query.Page < 1 || query.PageSize < 1 || query.PageSize > MaxPageSize)
        {
            throw new ValidationException("Page debe ser mayor o igual que uno y PageSize debe estar entre uno y 50.");
        }

        if (query.Type.HasValue && !Enum.IsDefined(typeof(NotificationType), query.Type.Value))
        {
            throw new ValidationException("Type no es válido.");
        }
    }

    private static NotificationResponseDto ToDto(Notification notification) => new(
        notification.Id,
        notification.Type,
        notification.Title,
        notification.Body,
        notification.ReadAt is not null,
        notification.ReadAt,
        notification.CreatedAt,
        ParseTarget(notification.DataJson));

    private static string? SerializeTarget(NotificationTargetDto? target)
    {
        if (target is null)
        {
            return null;
        }

        ValidateTarget(target);
        return JsonSerializer.Serialize(target, JsonOptions);
    }

    private static NotificationTargetDto? ParseTarget(string? dataJson)
    {
        if (string.IsNullOrWhiteSpace(dataJson))
        {
            return null;
        }

        try
        {
            var target = JsonSerializer.Deserialize<NotificationTargetDto>(dataJson, JsonOptions);
            if (target is null)
            {
                return null;
            }

            ValidateTarget(target);
            return target;
        }
        catch (JsonException)
        {
            return null;
        }
        catch (ValidationException)
        {
            return null;
        }
    }

    private static void ValidateTarget(NotificationTargetDto target)
    {
        if (target.ResourceId == Guid.Empty || !IsSupportedResourceType(target.ResourceType))
        {
            throw new ValidationException("El destino de la notificación no es válido.");
        }
    }

    private static bool IsSupportedResourceType(string? resourceType)
        => resourceType is "TheftReport" or "Product" or "Workshop";
}