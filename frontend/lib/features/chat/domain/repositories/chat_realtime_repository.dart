import '../entities/chat_entities.dart';

enum ChatRealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

abstract interface class ChatRealtimeRepository {
  Stream<ChatMessage> get messages;
  Stream<ChatRealtimeConnectionState> get connectionStates;

  Future<void> start();
  Future<void> stop();
  Future<void> joinConversation(String conversationId);
  Future<void> leaveConversation(String conversationId);
}
