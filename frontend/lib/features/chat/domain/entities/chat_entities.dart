enum ConversationType { direct, group, marketplace, unknown }

enum ChatMessageType { text, image, file, system, unknown }

class ChatParticipant {
  const ChatParticipant({required this.userId, required this.displayName, this.profileImageUrl});

  final String userId;
  final String displayName;
  final String? profileImageUrl;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderDisplayName,
    required this.senderProfileImageUrl,
    required this.content,
    required this.messageType,
    required this.sentAt,
    required this.replyToMessageId,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderDisplayName;
  final String? senderProfileImageUrl;
  final String content;
  final ChatMessageType messageType;
  final DateTime sentAt;
  final String? replyToMessageId;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.lastMessageAt,
    required this.participant,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String id;
  final ConversationType type;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final ChatParticipant participant;
  final ChatMessage? lastMessage;
  final int unreadCount;
}

class PagedMessages {
  const PagedMessages({required this.items, required this.page, required this.pageSize, required this.totalCount, required this.totalPages});

  final List<ChatMessage> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
