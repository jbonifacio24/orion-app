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
  Stream<RouteLocation> get routeLocations => const Stream<RouteLocation>.empty();

  Future<void> start();
  Future<void> stop();
  Future<void> joinConversation(String conversationId);
  Future<void> leaveConversation(String conversationId);
  Future<void> publishRouteLocation(String conversationId, {required double latitude, required double longitude}) async {}
}
