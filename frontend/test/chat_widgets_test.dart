import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/chat/domain/entities/chat_entities.dart';
import 'package:motohub/features/chat/presentation/widgets/conversation_tile.dart';
import 'package:motohub/features/chat/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('message bubble distinguishes own and other messages', (tester) async {
    final message = ChatMessage(
      id: 'message-id',
      conversationId: 'conversation-id',
      senderUserId: 'sender-id',
      senderDisplayName: 'Ana',
      senderProfileImageUrl: null,
      content: 'Hola',
      messageType: ChatMessageType.text,
      sentAt: DateTime.utc(2026, 1, 1, 10),
      replyToMessageId: null,
    );

    await tester.pumpWidget(MaterialApp(home: MessageBubble(message: message, isMine: false)));

    expect(find.text('Hola'), findsOneWidget);
    final local = message.sentAt.toLocal();
    final expectedTime = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(find.text(expectedTime), findsOneWidget);
  });

  testWidgets('conversation tile displays unread badge and participant', (tester) async {
    final conversation = Conversation(
      id: 'conversation-id',
      type: ConversationType.direct,
      createdAt: DateTime.utc(2026),
      lastMessageAt: null,
      participant: const ChatParticipant(userId: 'user-id', displayName: 'Ana'),
      lastMessage: null,
      unreadCount: 2,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ConversationTile(conversation: conversation, onTap: () {}))));

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}
