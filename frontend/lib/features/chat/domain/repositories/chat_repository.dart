import '../entities/chat_entities.dart';

abstract interface class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation> getOrCreateDirectConversation(String recipientUserId);
  Future<PagedMessages> getMessages({required String conversationId, required int page, int pageSize = 20});
  Future<ChatMessage> sendMessage({required String conversationId, required String content});
  Future<void> markConversationRead(String conversationId);
}
