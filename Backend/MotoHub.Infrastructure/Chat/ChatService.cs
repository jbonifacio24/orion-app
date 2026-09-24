using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MotoHub.Application.Chat;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Chat;

public sealed class ChatService(
    MotoHubDbContext dbContext,
    IChatRealtimeNotifier? realtimeNotifier = null,
    ILogger<ChatService>? logger = null) : IChatService
{
    private const int MaxPageSize = 50;

    public async Task<IReadOnlyCollection<ConversationResponseDto>> GetConversationsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var participants = await dbContext.ConversationParticipants
            .AsNoTrackingWithIdentityResolution()
            .Where(x => x.UserId == userId && x.LeftAt == null && x.Conversation.Type == ConversationType.Direct)
            .Include(x => x.Conversation)
                .ThenInclude(x => x.Participants)
                    .ThenInclude(x => x.User)
            .ToListAsync(cancellationToken);

        var conversations = participants
            .Select(x => new ConversationListItem(
                x.Conversation,
                x.Conversation.Participants
                    .Where(participant => participant.UserId != userId && participant.LeftAt == null)
                    .Select(participant => participant.User)
                    .SingleOrDefault()!,
                x))
            .Where(x => x.OtherParticipant is not null)
            .OrderByDescending(x => x.Conversation.LastMessageAt ?? x.Conversation.CreatedAt)
            .ThenByDescending(x => x.Conversation.Id)
            .ToArray();

        var conversationIds = conversations.Select(x => x.Conversation.Id).ToArray();
        var lastMessages = await GetLastMessagesAsync(conversationIds, cancellationToken);
        var unreadCounts = await GetUnreadCountsAsync(conversations, userId, cancellationToken);

        return conversations.Select(x => new ConversationResponseDto(
            x.Conversation.Id,
            x.Conversation.Type,
            x.Conversation.CreatedAt,
            x.Conversation.LastMessageAt,
            ToParticipantDto(x.OtherParticipant),
            lastMessages.GetValueOrDefault(x.Conversation.Id),
            unreadCounts.GetValueOrDefault(x.Conversation.Id))).ToArray();
    }

        public async Task<ConversationResponseDto> GetOrCreateDirectAsync(
            Guid userId,
            DirectConversationRequest request,
            CancellationToken cancellationToken)
        {
            if (request.RecipientUserId == Guid.Empty || request.RecipientUserId == userId)
            {
                throw new ValidationException("RecipientUserId debe corresponder a otro usuario válido.");
            }

            var recipient = await dbContext.Users
                .SingleOrDefaultAsync(x => x.Id == request.RecipientUserId, cancellationToken)
                ?? throw new ResourceNotFoundException("El usuario destinatario no existe.");

            var existing = await dbContext.Conversations
                .Include(x => x.Participants)
                    .ThenInclude(x => x.User)
                .Where(x => x.Type == ConversationType.Direct &&
                            x.Participants.Count(participant => participant.LeftAt == null) == 2 &&
                            x.Participants.Any(participant => participant.UserId == userId && participant.LeftAt == null) &&
                            x.Participants.Any(participant => participant.UserId == request.RecipientUserId && participant.LeftAt == null))
                .SingleOrDefaultAsync(cancellationToken);

            if (existing is not null)
            {
                return await ToConversationDtoAsync(existing, userId, cancellationToken);
            }

            var currentUser = await dbContext.Users
                .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
                ?? throw new ResourceNotFoundException("El usuario actual no existe.");
            var conversation = new Conversation { Type = ConversationType.Direct };
            conversation.Participants.Add(new ConversationParticipant
            {
                ConversationId = conversation.Id,
                UserId = userId,
                JoinedAt = DateTimeOffset.UtcNow,
                User = currentUser
            });
            conversation.Participants.Add(new ConversationParticipant
            {
                ConversationId = conversation.Id,
                UserId = request.RecipientUserId,
                JoinedAt = DateTimeOffset.UtcNow,
                User = recipient
            });

            dbContext.Conversations.Add(conversation);
            await dbContext.SaveChangesAsync(cancellationToken);
            return await ToConversationDtoAsync(conversation, userId, cancellationToken);
        }

        public async Task<PagedResponse<MessageResponseDto>> GetMessagesAsync(
            Guid userId,
            Guid conversationId,
            MessageListQueryDto query,
            CancellationToken cancellationToken)
        {
            ValidateQuery(query);
            await GetActiveDirectConversationAsync(userId, conversationId, cancellationToken);

            var messages = dbContext.Messages
                .AsNoTracking()
                .Where(x => x.ConversationId == conversationId)
                .Include(x => x.Sender);
            var totalCount = await messages.CountAsync(cancellationToken);
            var items = await messages
                .OrderByDescending(x => x.SentAt)
                .ThenByDescending(x => x.Id)
                .Skip((query.Page - 1) * query.PageSize)
                .Take(query.PageSize)
                .ToListAsync(cancellationToken);
            var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);

            return new PagedResponse<MessageResponseDto>(
                items.Select(ToMessageDto).ToArray(), query.Page, query.PageSize, totalCount, totalPages);
        }

        public async Task<MessageResponseDto> SendMessageAsync(
            Guid userId,
            Guid conversationId,
            SendMessageRequest request,
            CancellationToken cancellationToken)
        {
            var content = request.Content?.Trim() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(content) || content.Length > 10000)
            {
                throw new ValidationException("Content es obligatorio y debe tener como máximo 10000 caracteres.");
            }

            var conversation = await GetActiveDirectConversationAsync(userId, conversationId, cancellationToken);
            var sender = await dbContext.Users
                .SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
                ?? throw new ResourceNotFoundException("El usuario actual no existe.");
            var sentAt = DateTimeOffset.UtcNow;
            var message = new Message
            {
                ConversationId = conversation.Id,
                SenderUserId = userId,
                Content = content,
                MessageType = MessageType.Text,
                SentAt = sentAt,
                Sender = sender
            };
            conversation.LastMessageAt = sentAt;
            dbContext.Messages.Add(message);
            await dbContext.SaveChangesAsync(cancellationToken);
            var response = ToMessageDto(message);
            if (realtimeNotifier is not null)
            {
                try
                {
                    await realtimeNotifier.NotifyMessageReceivedAsync(response, cancellationToken);
                }
                catch (Exception exception)
                {
                    logger?.LogError(exception,
                        "Chat realtime notification failed for persisted message {MessageId}.", response.Id);
                }
            }

            return response;
        }

        public async Task MarkReadAsync(Guid userId, Guid conversationId, CancellationToken cancellationToken)
        {
            var participant = await dbContext.ConversationParticipants
                .SingleOrDefaultAsync(x => x.ConversationId == conversationId && x.UserId == userId &&
                                           x.LeftAt == null && x.Conversation.Type == ConversationType.Direct,
                    cancellationToken)
                ?? throw new ResourceNotFoundException("La conversación no existe.");

            participant.LastReadAt = DateTimeOffset.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        public async Task EnsureActiveParticipantAsync(Guid userId, Guid conversationId, CancellationToken cancellationToken)
            => await GetActiveDirectConversationAsync(userId, conversationId, cancellationToken);

        private async Task<Conversation> GetActiveDirectConversationAsync(Guid userId, Guid conversationId, CancellationToken cancellationToken)
            => await dbContext.Conversations
                .SingleOrDefaultAsync(x => x.Id == conversationId && x.Type == ConversationType.Direct &&
                                           x.Participants.Any(participant => participant.UserId == userId && participant.LeftAt == null),
                    cancellationToken)
               ?? throw new ResourceNotFoundException("La conversación no existe.");

        private async Task<ConversationResponseDto> ToConversationDtoAsync(Conversation conversation, Guid userId, CancellationToken cancellationToken)
        {
            var otherParticipant = conversation.Participants
                .Where(x => x.UserId != userId && x.LeftAt == null)
                .Select(x => x.User)
                .SingleOrDefault()
                ?? throw new ResourceNotFoundException("La conversación no tiene un participante válido.");
            var lastMessageEntity = await dbContext.Messages
                .AsNoTracking()
                .Where(x => x.ConversationId == conversation.Id)
                .Include(x => x.Sender)
                .OrderByDescending(x => x.SentAt)
                .ThenByDescending(x => x.Id)
                .FirstOrDefaultAsync(cancellationToken);
            var currentParticipant = conversation.Participants.Single(x => x.UserId == userId && x.LeftAt == null);
            var unreadCount = await GetUnreadCountAsync(conversation.Id, userId, currentParticipant.LastReadAt ?? currentParticipant.JoinedAt, cancellationToken);
            return new ConversationResponseDto(conversation.Id, conversation.Type, conversation.CreatedAt, conversation.LastMessageAt,
                ToParticipantDto(otherParticipant), lastMessageEntity is null ? null : ToMessageDto(lastMessageEntity), unreadCount);
        }

        private async Task<Dictionary<Guid, MessageResponseDto>> GetLastMessagesAsync(Guid[] conversationIds, CancellationToken cancellationToken)
        {
            if (conversationIds.Length == 0) return [];
            var messages = await dbContext.Messages
                .AsNoTracking()
                .Where(x => conversationIds.Contains(x.ConversationId))
                .Include(x => x.Sender)
                .OrderByDescending(x => x.SentAt)
                .ThenByDescending(x => x.Id)
                .ToListAsync(cancellationToken);
            return messages.GroupBy(x => x.ConversationId).ToDictionary(x => x.Key, x => ToMessageDto(x.First()));
        }

        private async Task<Dictionary<Guid, int>> GetUnreadCountsAsync(
            IEnumerable<ConversationListItem> conversations,
            Guid userId,
            CancellationToken cancellationToken)
        {
            var result = new Dictionary<Guid, int>();
            foreach (var conversation in conversations)
            {
                result[conversation.Conversation.Id] = await GetUnreadCountAsync(
                    conversation.Conversation.Id,
                    userId,
                    conversation.CurrentParticipant.LastReadAt ?? conversation.CurrentParticipant.JoinedAt,
                    cancellationToken);
            }
            return result;
        }

        private Task<int> GetUnreadCountAsync(Guid conversationId, Guid userId, DateTimeOffset joinedOrReadAt, CancellationToken cancellationToken)
            => dbContext.Messages.CountAsync(x => x.ConversationId == conversationId && x.SenderUserId != userId &&
                                                  x.SentAt > joinedOrReadAt, cancellationToken);

        private static ConversationParticipantResponseDto ToParticipantDto(User user)
            => new(user.Id, DisplayName(user), user.ProfileImageUrl);

        private static MessageResponseDto ToMessageDto(Message message)
            => new(message.Id, message.ConversationId, message.SenderUserId, DisplayName(message.Sender),
                message.Sender.ProfileImageUrl, message.Content, message.MessageType, message.SentAt, null);

        private static string DisplayName(User user)
        {
            var name = string.Join(" ", new[] { user.FirstName, user.LastName }.Where(x => !string.IsNullOrWhiteSpace(x)));
            return string.IsNullOrWhiteSpace(name) ? user.UserName : name;
        }

        private static void ValidateQuery(MessageListQueryDto query)
        {
            if (query.Page < 1 || query.PageSize < 1 || query.PageSize > MaxPageSize)
            {
                throw new ValidationException("Page debe ser mayor o igual que uno y PageSize debe estar entre uno y 50.");
            }
        }

        private sealed record ConversationListItem(
            Conversation Conversation,
            User OtherParticipant,
            ConversationParticipant CurrentParticipant);
}
