using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Notifications;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/notifications")]
public sealed class NotificationsController(INotificationService notificationService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<PagedResponse<NotificationResponseDto>> Get(
        [FromQuery] NotificationListQueryDto query,
        CancellationToken cancellationToken)
        => notificationService.GetAsync(CurrentUserId(), query, cancellationToken);

    [HttpGet("unread-count")]
    public Task<UnreadNotificationCountDto> GetUnreadCount(CancellationToken cancellationToken)
        => notificationService.GetUnreadCountAsync(CurrentUserId(), cancellationToken);

    [HttpPatch("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken cancellationToken)
    {
        await notificationService.MarkAllReadAsync(CurrentUserId(), cancellationToken);
        return NoContent();
    }

    [HttpPatch("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken cancellationToken)
    {
        await notificationService.MarkReadAsync(CurrentUserId(), id, cancellationToken);
        return NoContent();
    }
}