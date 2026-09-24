using MotoHub.Application.Marketplace;
using MotoHub.Domain;

namespace MotoHub.Application.Notifications;

public interface INotificationService
{
    Task<PagedResponse<NotificationResponseDto>> GetAsync(Guid userId, NotificationListQueryDto query, CancellationToken cancellationToken);
    Task<UnreadNotificationCountDto> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken);
    Task MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken);
    Task MarkAllReadAsync(Guid userId, CancellationToken cancellationToken);
    Task<Guid> CreateAsync(CreateNotificationRequest request, CancellationToken cancellationToken);
}

public sealed record NotificationListQueryDto(
    int Page = 1,
    int PageSize = 20,
    bool UnreadOnly = false,
    NotificationType? Type = null);

public sealed record NotificationTargetDto(string ResourceType, Guid ResourceId);

public sealed record NotificationResponseDto(
    Guid Id,
    NotificationType Type,
    string Title,
    string Body,
    bool IsRead,
    DateTimeOffset? ReadAt,
    DateTimeOffset CreatedAt,
    NotificationTargetDto? Target);

public sealed record UnreadNotificationCountDto(int Count);

public sealed record CreateNotificationRequest(
    Guid RecipientUserId,
    Guid? ActorUserId,
    NotificationType Type,
    string Title,
    string Body,
    NotificationTargetDto? Target = null,
    DateTimeOffset? ExpiresAt = null);