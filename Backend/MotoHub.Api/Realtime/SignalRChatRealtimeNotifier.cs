using Microsoft.AspNetCore.SignalR;
using MotoHub.Api.Hubs;
using MotoHub.Application.Chat;

namespace MotoHub.Api.Realtime;

public sealed class SignalRChatRealtimeNotifier(IHubContext<ChatHub> hubContext) : IChatRealtimeNotifier
{
    public Task NotifyMessageReceivedAsync(MessageResponseDto message, CancellationToken cancellationToken)
        => hubContext.Clients
            .Group(ChatGroupNames.Conversation(message.ConversationId))
            .SendAsync("MessageReceived", message, cancellationToken);
}