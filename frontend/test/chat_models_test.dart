import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/chat/data/models/chat_models.dart';
import 'package:motohub/features/chat/domain/entities/chat_entities.dart';

void main() {
  test('parses the backend conversation contract and nullable last message', () {
    final conversation = ConversationModel.fromJson({
      'id': 'conversation-id',
      'type': 0,
      'createdAt': '2026-09-23T10:00:00Z',
      'lastMessageAt': null,
      'participant': {'userId': 'user-id', 'displayName': 'Ana', 'profileImageUrl': null},
      'lastMessage': null,
      'unreadCount': 3,
    });

    expect(conversation.type, ConversationType.direct);
    expect(conversation.participant.userId, 'user-id');
    expect(conversation.lastMessage, isNull);
    expect(conversation.unreadCount, 3);
  });

  test('parses message enums defensively and preserves nullable reply', () {
    final message = ChatMessageModel.fromJson({
      'id': 'message-id',
      'conversationId': 'conversation-id',
      'senderUserId': 'sender-id',
      'senderDisplayName': 'Ana',
      'senderProfileImageUrl': '/ana.png',
      'content': 'Hola',
      'messageType': 'Text',
      'sentAt': '2026-09-23T10:00:00Z',
      'replyToMessageId': null,
    });
    final unknown = ChatMessageModel.fromJson({
      'id': 'unknown-id',
      'conversationId': 'conversation-id',
      'senderUserId': 'sender-id',
      'sentAt': '2026-09-23T10:00:00Z',
      'messageType': 99,
    });

    expect(message.messageType, ChatMessageType.text);
    expect(message.sentAt.isUtc, isTrue);
    expect(message.replyToMessageId, isNull);
    expect(unknown.messageType, ChatMessageType.unknown);
  });

  test('parses paged messages and rejects structurally invalid items', () {
    final page = PagedMessagesModel.fromJson({
      'items': [
        {
          'id': 'message-id',
          'conversationId': 'conversation-id',
          'senderUserId': 'sender-id',
          'sentAt': '2026-09-23T10:00:00Z',
          'messageType': 0,
        }
      ],
      'page': 2,
      'pageSize': 20,
      'totalCount': 21,
      'totalPages': 2,
    });

    expect(page.page, 2);
    expect(page.items, hasLength(1));
    expect(() => PagedMessagesModel.fromJson({'items': 'invalid'}), throwsA(isA<Exception>()));
  });
}
