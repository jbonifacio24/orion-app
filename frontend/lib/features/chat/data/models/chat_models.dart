import '../../../../core/error/app_failure.dart';
import '../../domain/entities/chat_entities.dart';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  throw SerializationFailure('La fecha $key no es válida.');
}

DateTime? _optionalDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

int? _enumIndex(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

ConversationType _conversationType(Object? value) {
  final index = _enumIndex(value);
  if (index != null) {
    return switch (index) {
      0 => ConversationType.direct,
      1 => ConversationType.group,
      2 => ConversationType.marketplace,
      _ => ConversationType.unknown,
    };
  }
  return switch (value?.toString().toLowerCase()) {
    'direct' => ConversationType.direct,
    'group' => ConversationType.group,
    'marketplace' => ConversationType.marketplace,
    _ => ConversationType.unknown,
  };
}

ChatMessageType _messageType(Object? value) {
  final index = _enumIndex(value);
  if (index != null) {
    return switch (index) {
      0 => ChatMessageType.text,
      1 => ChatMessageType.image,
      2 => ChatMessageType.file,
      3 => ChatMessageType.system,
      _ => ChatMessageType.unknown,
    };
  }
  return switch (value?.toString().toLowerCase()) {
    'text' => ChatMessageType.text,
    'image' => ChatMessageType.image,
    'file' => ChatMessageType.file,
    'system' => ChatMessageType.system,
    _ => ChatMessageType.unknown,
  };
}

class ChatParticipantModel extends ChatParticipant {
  const ChatParticipantModel({required super.userId, required super.displayName, super.profileImageUrl});

  factory ChatParticipantModel.fromJson(Map<String, dynamic> json) => ChatParticipantModel(
        userId: _requiredString(json, 'userId'),
        displayName: json['displayName'] as String? ?? '',
        profileImageUrl: json['profileImageUrl'] as String?,
      );
}

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({required super.id, required super.conversationId, required super.senderUserId, required super.senderDisplayName, required super.senderProfileImageUrl, required super.content, required super.messageType, required super.sentAt, required super.replyToMessageId});

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
        id: _requiredString(json, 'id'),
        conversationId: _requiredString(json, 'conversationId'),
        senderUserId: _requiredString(json, 'senderUserId'),
        senderDisplayName: json['senderDisplayName'] as String? ?? '',
        senderProfileImageUrl: json['senderProfileImageUrl'] as String?,
        content: json['content'] as String? ?? '',
        messageType: _messageType(json['messageType']),
        sentAt: _requiredDate(json, 'sentAt'),
        replyToMessageId: json['replyToMessageId'] as String?,
      );
}

class ConversationModel extends Conversation {
  const ConversationModel({required super.id, required super.type, required super.createdAt, required super.lastMessageAt, required super.participant, required super.lastMessage, required super.unreadCount});

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawParticipant = json['participant'];
    if (rawParticipant is! Map<String, dynamic>) {
      throw const SerializationFailure('La conversación no tiene un participante válido.');
    }
    final rawLastMessage = json['lastMessage'];
    return ConversationModel(
      id: _requiredString(json, 'id'),
      type: _conversationType(json['type']),
      createdAt: _requiredDate(json, 'createdAt'),
      lastMessageAt: _optionalDate(json['lastMessageAt']),
      participant: ChatParticipantModel.fromJson(rawParticipant),
      lastMessage: rawLastMessage is Map<String, dynamic> ? ChatMessageModel.fromJson(rawLastMessage) : null,
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] as int : 0,
    );
  }
}

class PagedMessagesModel extends PagedMessages {
  const PagedMessagesModel({required super.items, required super.page, required super.pageSize, required super.totalCount, required super.totalPages});

  factory PagedMessagesModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const SerializationFailure('La respuesta de mensajes no tiene una lista válida.');
    }
    return PagedMessagesModel(
      items: rawItems.map((item) {
        if (item is! Map<String, dynamic>) throw const SerializationFailure('La respuesta contiene un mensaje inválido.');
        return ChatMessageModel.fromJson(item);
      }).toList(growable: false),
      page: json['page'] is int ? json['page'] as int : 1,
      pageSize: json['pageSize'] is int ? json['pageSize'] as int : 20,
      totalCount: json['totalCount'] is int ? json['totalCount'] as int : 0,
      totalPages: json['totalPages'] is int ? json['totalPages'] as int : 0,
    );
  }
}
