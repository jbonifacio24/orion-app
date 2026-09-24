using MotoHub.Application.Marketplace;
using MotoHub.Domain;

namespace MotoHub.Application.Chat;

public interface IChatService
{
    Task<IReadOnlyCollection<ConversationResponseDto>> GetConversationsAsync(Guid userId, CancellationToken cancellationToken);
    Task<ConversationResponseDto> GetOrCreateDirectAsync(Guid userId, DirectConversationRequest request, CancellationToken cancellationToken);
    Task<PagedResponse<MessageResponseDto>> GetMessagesAsync(Guid userId, Guid conversationId, MessageListQueryDto query, CancellationToken cancellationToken);
    Task<MessageResponseDto> SendMessageAsync(Guid userId, Guid conversationId, SendMessageRequest request, CancellationToken cancellationToken);
    Task MarkReadAsync(Guid userId, Guid conversationId, CancellationToken cancellationToken);
    Task EnsureActiveParticipantAsync(Guid userId, Guid conversationId, CancellationToken cancellationToken);
}

public interface IChatRealtimeNotifier
{
    Task NotifyMessageReceivedAsync(MessageResponseDto message, CancellationToken cancellationToken);
}

public static class ChatGroupNames
{
    public static string Conversation(Guid conversationId) => $"conversation:{conversationId:D}";
}

public sealed record DirectConversationRequest(Guid RecipientUserId);

public sealed record MessageListQueryDto(int Page = 1, int PageSize = 20);

public sealed record SendMessageRequest(string? Content);

public sealed record ConversationResponseDto(
    Guid Id,
    ConversationType Type,
    DateTimeOffset CreatedAt,
    DateTimeOffset? LastMessageAt,
    ConversationParticipantResponseDto Participant,
    MessageResponseDto? LastMessage,
    int UnreadCount);

public sealed record ConversationParticipantResponseDto(
    Guid UserId,
    string DisplayName,
    string? ProfileImageUrl);

public sealed record MessageResponseDto(
    Guid Id,
    Guid ConversationId,
    Guid SenderUserId,
    string SenderDisplayName,
    string? SenderProfileImageUrl,
    string Content,
    MessageType MessageType,
    DateTimeOffset SentAt,
    Guid? ReplyToMessageId);
