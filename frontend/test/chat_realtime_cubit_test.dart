import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/chat/domain/entities/chat_entities.dart';
import 'package:motohub/features/chat/domain/repositories/chat_realtime_repository.dart';
import 'package:motohub/features/chat/domain/repositories/chat_repository.dart';
import 'package:motohub/features/chat/domain/usecases/chat_usecases.dart';
import 'package:motohub/features/chat/presentation/cubit/chat_cubit.dart';

void main() {
  test('active realtime messages merge, ignore other conversations, and deduplicate echo', () async {
    final realtime = _FakeRealtime();
    final repository = _FakeChatRepository();
    final cubit = _createCubit(repository, realtime);
    addTearDown(cubit.close);

    await cubit.load('conversation-a');
    final message = _message('message-1', 'conversation-a', DateTime.utc(2026, 1, 2));
    realtime.emitMessage(message);
    realtime.emitMessage(_message('other-message', 'conversation-b', DateTime.utc(2026, 1, 3)));
    realtime.emitMessage(message);
    await _settleAsyncWork();

    expect(cubit.state.items.map((item) => item.id), ['message-1']);
    await cubit.send('echo');
    realtime.emitMessage(repository.lastSent!);
    await _settleAsyncWork();
    expect(cubit.state.items.map((item) => item.id), ['message-1', 'sent-message']);
  });

  test('realtime merge preserves SentAt then Id ordering', () async {
    final realtime = _FakeRealtime();
    final cubit = _createCubit(_FakeChatRepository(), realtime);
    addTearDown(cubit.close);

    await cubit.load('conversation-a');
    realtime.emitMessage(_message('z', 'conversation-a', DateTime.utc(2026, 1, 2)));
    realtime.emitMessage(_message('a', 'conversation-a', DateTime.utc(2026, 1, 1)));
    realtime.emitMessage(_message('b', 'conversation-a', DateTime.utc(2026, 1, 2)));
    await _settleAsyncWork();

    expect(cubit.state.items.map((item) => item.id), ['a', 'b', 'z']);
  });

  test('reconnect rejoins the active conversation and resynchronizes through REST', () async {
    final realtime = _FakeRealtime();
    final repository = _FakeChatRepository();
    final cubit = _createCubit(repository, realtime);
    addTearDown(cubit.close);

    await cubit.load('conversation-a');
    realtime.emitConnection(ChatRealtimeConnectionState.reconnecting);
    realtime.emitConnection(ChatRealtimeConnectionState.connected);
    await _settleAsyncWork();

    expect(realtime.joinedConversationIds, ['conversation-a', 'conversation-a']);
    expect(repository.getMessagesCalls, 2);
  });

  test('a realtime message arriving during REST history load is preserved', () async {
    final pending = Completer<PagedMessages>();
    final realtime = _FakeRealtime();
    final repository = _FakeChatRepository(messagesFuture: pending.future);
    final cubit = _createCubit(repository, realtime);
    addTearDown(cubit.close);

    final load = cubit.load('conversation-a');
    realtime.emitMessage(_message('realtime-during-load', 'conversation-a', DateTime.utc(2026, 1, 1)));
    await _settleAsyncWork();
    pending.complete(const PagedMessages(items: [], page: 1, pageSize: 20, totalCount: 0, totalPages: 0));
    await load;

    expect(cubit.state.items.map((item) => item.id), ['realtime-during-load']);
  });

  test('closing the cubit leaves the conversation and ignores later events', () async {
    final realtime = _FakeRealtime();
    final cubit = _createCubit(_FakeChatRepository(), realtime);

    await cubit.load('conversation-a');
    await cubit.close();
    realtime.emitMessage(_message('late', 'conversation-a', DateTime.utc(2026, 1, 4)));

    expect(realtime.leftConversationIds, ['conversation-a']);
  });
}

ChatCubit _createCubit(ChatRepository repository, ChatRealtimeRepository realtime) => ChatCubit(
      GetMessages(repository),
      SendMessage(repository),
      MarkConversationRead(repository),
      realtime,
    );

ChatMessage _message(String id, String conversationId, DateTime sentAt) => ChatMessage(
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

class _FakeRealtime implements ChatRealtimeRepository {
  final _messages = StreamController<ChatMessage>.broadcast();
  final _states = StreamController<ChatRealtimeConnectionState>.broadcast();
  final joinedConversationIds = <String>[];
  final leftConversationIds = <String>[];

  @override
  Stream<ChatMessage> get messages => _messages.stream;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates => _states.stream;

  @override
  Future<void> start() async => emitConnection(ChatRealtimeConnectionState.connected);

  @override
  Future<void> stop() async {}

  @override
  Future<void> joinConversation(String conversationId) async => joinedConversationIds.add(conversationId);

  @override
  Future<void> leaveConversation(String conversationId) async => leftConversationIds.add(conversationId);

  void emitMessage(ChatMessage message) => _messages.add(message);

  void emitConnection(ChatRealtimeConnectionState state) => _states.add(state);
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.messagesFuture});

  final Future<PagedMessages>? messagesFuture;
  int getMessagesCalls = 0;
  ChatMessage? lastSent;

  @override
  Future<List<Conversation>> getConversations() async => [];

  @override
  Future<Conversation> getOrCreateDirectConversation(String recipientUserId) async => throw UnimplementedError();

  @override
  Future<PagedMessages> getMessages({required String conversationId, required int page, int pageSize = 20}) async {
    getMessagesCalls++;
    final pending = messagesFuture;
    if (pending != null) return pending;
    return PagedMessages(
      items: const [],
      page: page,
      pageSize: pageSize,
      totalCount: 0,
      totalPages: 0,
    );
  }

  @override
  Future<ChatMessage> sendMessage({required String conversationId, required String content}) async {
    lastSent = _message('sent-message', conversationId, DateTime.utc(2026, 1, 3));
    return lastSent!;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {}
}

Future<void> _settleAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
