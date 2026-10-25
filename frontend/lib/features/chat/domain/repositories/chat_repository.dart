import '../entities/chat_entities.dart';
import 'package:file_picker/file_picker.dart';

abstract interface class ChatRepository {
  Future<List<Conversation>> getConversations();
  Future<Conversation> getOrCreateDirectConversation(String recipientUserId);
  Future<PagedMessages> getMessages({required String conversationId, required int page, int pageSize = 20});
  Future<ChatMessage> sendMessage({required String conversationId, required String content});
  Future<ChatMessage> sendAttachment({required String conversationId, required PlatformFile file});
  Future<void> markConversationRead(String conversationId);
}
