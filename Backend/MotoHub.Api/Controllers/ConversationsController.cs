using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Chat;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/conversations")]
public sealed class ConversationsController(IChatService chatService) : CurrentUserControllerBase
{
    [HttpGet]
    public Task<IReadOnlyCollection<ConversationResponseDto>> Get(CancellationToken cancellationToken)
        => chatService.GetConversationsAsync(CurrentUserId(), cancellationToken);

    [HttpPost("direct")]
    public async Task<IActionResult> GetOrCreateDirect(
        DirectConversationRequest request,
        CancellationToken cancellationToken)
    {
        var conversation = await chatService.GetOrCreateDirectAsync(CurrentUserId(), request, cancellationToken);
        return Ok(conversation);
    }

    [HttpGet("{conversationId:guid}/messages")]
    public Task<PagedResponse<MessageResponseDto>> GetMessages(
        Guid conversationId,
        [FromQuery] MessageListQueryDto query,
        CancellationToken cancellationToken)
        => chatService.GetMessagesAsync(CurrentUserId(), conversationId, query, cancellationToken);

    [HttpPost("{conversationId:guid}/messages")]
    public async Task<IActionResult> SendMessage(
        Guid conversationId,
        SendMessageRequest request,
        CancellationToken cancellationToken)
    {
        var message = await chatService.SendMessageAsync(CurrentUserId(), conversationId, request, cancellationToken);
        return Ok(message);
    }

    [HttpPatch("{conversationId:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid conversationId, CancellationToken cancellationToken)
    {
        await chatService.MarkReadAsync(CurrentUserId(), conversationId, cancellationToken);
        return NoContent();
    }
}
