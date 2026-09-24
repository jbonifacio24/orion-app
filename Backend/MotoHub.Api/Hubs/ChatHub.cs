using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using MotoHub.Application.Chat;
using MotoHub.Application.Errors;

namespace MotoHub.Api.Hubs;

[Authorize]
public sealed class ChatHub(IChatService chatService) : Hub
{
    public async Task JoinConversation(Guid conversationId)
    {
        var userId = CurrentUserId();
        await chatService.EnsureActiveParticipantAsync(userId, conversationId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, ChatGroupNames.Conversation(conversationId));
    }

    public async Task LeaveConversation(Guid conversationId)
    {
        var userId = CurrentUserId();
        await chatService.EnsureActiveParticipantAsync(userId, conversationId, Context.ConnectionAborted);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, ChatGroupNames.Conversation(conversationId));
    }

    private Guid CurrentUserId()
    {
        var value = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier) ??
                    Context.User?.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new HubException("The authenticated user identity is invalid.");
    }
}