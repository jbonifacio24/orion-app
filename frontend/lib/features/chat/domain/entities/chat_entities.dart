enum ConversationType { direct, group, marketplace, unknown }

enum ChatMessageType { text, image, file, system, unknown }

class RouteLocation {
  const RouteLocation({required this.conversationId, required this.userId, required this.displayName, required this.latitude, required this.longitude, required this.updatedAt});

  final String conversationId;
  final String userId;
  final String displayName;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;
}

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
    this.attachments = const [],
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
  final List<ChatAttachment> attachments;
}

class ChatAttachment {
  const ChatAttachment({required this.id, required this.url, required this.fileName, required this.contentType, required this.sizeBytes});
  final String id;
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;
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
    this.title,
    this.participantCount = 0,
  });

  final String id;
  final ConversationType type;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final ChatParticipant participant;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final String? title;
  final int participantCount;
}

class PagedMessages {
  const PagedMessages({required this.items, required this.page, required this.pageSize, required this.totalCount, required this.totalPages});

  final List<ChatMessage> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
