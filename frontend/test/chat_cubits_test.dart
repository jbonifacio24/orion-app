import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/chat/domain/entities/chat_entities.dart';
import 'package:motohub/features/chat/domain/repositories/chat_repository.dart';
import 'package:motohub/features/chat/domain/usecases/chat_usecases.dart';
import 'package:motohub/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:motohub/features/chat/presentation/cubit/conversations_cubit.dart';

void main() {
  test('conversations clear prevents a stale load from repopulating state', () async {
    final pending = Completer<List<Conversation>>();
    final repository = _FakeChatRepository(conversationsFuture: pending.future);
    final cubit = ConversationsCubit(GetConversations(repository), GetOrCreateDirectConversation(repository));
    addTearDown(cubit.close);

    final load = cubit.load();
    cubit.clear();
    pending.complete([_conversation('conversation-id')]);
    await load;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.isInitialLoading, isFalse);
  });

  test('chat merges messages by id in deterministic chronological order', () async {
    final repository = _FakeChatRepository(
      messages: PagedMessages(
        items: [_message('new', DateTime.utc(2026, 1, 2)), _message('old', DateTime.utc(2026, 1, 1))],
        page: 1,
        pageSize: 20,
        totalCount: 2,
        totalPages: 1,
      ),
    );
    final cubit = ChatCubit(GetMessages(repository), SendMessage(repository), MarkConversationRead(repository));
    addTearDown(cubit.close);

    await cubit.load('conversation-id');
    cubit.receiveMessage(_message('new', DateTime.utc(2026, 1, 2)));

    expect(cubit.state.items.map((item) => item.id), ['old', 'new']);
    expect(cubit.state.items, hasLength(2));
  });

  test('chat clear prevents a stale history response from repopulating state', () async {
    final pending = Completer<PagedMessages>();
    final repository = _FakeChatRepository(messagesFuture: pending.future);
    final cubit = ChatCubit(GetMessages(repository), SendMessage(repository), MarkConversationRead(repository));
    addTearDown(cubit.close);

    final load = cubit.load('conversation-id');
    cubit.clear();
    pending.complete(const PagedMessages(items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0));
    await load;

    expect(cubit.state.conversationId, isNull);
    expect(cubit.state.items, isEmpty);
  });

  test('a new page-scoped chat cubit isolates B from A and sends to B', () async {
    final repository = _FakeChatRepository(
      messagesByConversation: {
        'conversation-a': PagedMessages(
          items: [_message('a-message', DateTime.utc(2026, 1, 1), conversationId: 'conversation-a')],
          page: 1,
          pageSize: 20,
          totalCount: 1,
          totalPages: 1,
        ),
        'conversation-b': const PagedMessages(items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0),
      },
    );
    final cubitA = ChatCubit(GetMessages(repository), SendMessage(repository), MarkConversationRead(repository));
    final cubitB = ChatCubit(GetMessages(repository), SendMessage(repository), MarkConversationRead(repository));
    addTearDown(cubitA.close);
    addTearDown(cubitB.close);

    await cubitA.load('conversation-a');
    expect(cubitA.state.items.map((item) => item.id), ['a-message']);
    expect(cubitB.state.items, isEmpty);

    await cubitB.load('conversation-b');
    await cubitB.send('Mensaje para B');

    expect(cubitB.state.items.map((item) => item.conversationId), ['conversation-b']);
    expect(repository.sentConversationIds, ['conversation-b']);
  });
}

Conversation _conversation(String id) => Conversation(
      id: id,
      type: ConversationType.direct,
      createdAt: DateTime.utc(2026),
      lastMessageAt: null,
      participant: const ChatParticipant(userId: 'user-id', displayName: 'Ana'),
      lastMessage: null,
      unreadCount: 0,
    );

ChatMessage _message(String id, DateTime sentAt, {String conversationId = 'conversation-id'}) => ChatMessage(
      id: id,
  conversationId: conversationId,
      senderUserId: 'sender-id',
      senderDisplayName: 'Ana',
      senderProfileImageUrl: null,
      content: id,
      messageType: ChatMessageType.text,
      sentAt: sentAt,
      replyToMessageId: null,
    );

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.conversationsFuture, this.messagesFuture, this.messages, this.messagesByConversation});

  final Future<List<Conversation>>? conversationsFuture;
  final Future<PagedMessages>? messagesFuture;
  final PagedMessages? messages;
  final Map<String, PagedMessages>? messagesByConversation;
  final sentConversationIds = <String>[];

  @override
  Future<List<Conversation>> getConversations() => conversationsFuture ?? Future.value([]);

  @override
  Future<Conversation> getOrCreateDirectConversation(String recipientUserId) => Future.value(_conversation('conversation-id'));

  @override
  Future<PagedMessages> getMessages({required String conversationId, required int page, int pageSize = 20}) => messagesByConversation?[conversationId] ?? messagesFuture ?? Future.value(messages!);

  @override
  Future<ChatMessage> sendMessage({required String conversationId, required String content}) {
    sentConversationIds.add(conversationId);
    return Future.value(_message('sent', DateTime.utc(2026, 1, 3), conversationId: conversationId));
  }

  @override
  Future<void> markConversationRead(String conversationId) async {}
}
