import '../entities/chat_entities.dart';
import '../repositories/chat_repository.dart';

class GetConversations {
  const GetConversations(this._repository);
  final ChatRepository _repository;
  Future<List<Conversation>> call() => _repository.getConversations();
}

class GetOrCreateDirectConversation {
  const GetOrCreateDirectConversation(this._repository);
  final ChatRepository _repository;
  Future<Conversation> call(String recipientUserId) => _repository.getOrCreateDirectConversation(recipientUserId);
}

class GetMessages {
  const GetMessages(this._repository);
  final ChatRepository _repository;
  Future<PagedMessages> call({required String conversationId, required int page, int pageSize = 20}) => _repository.getMessages(conversationId: conversationId, page: page, pageSize: pageSize);
}

class SendMessage {
  const SendMessage(this._repository);
  final ChatRepository _repository;
  Future<ChatMessage> call({required String conversationId, required String content}) => _repository.sendMessage(conversationId: conversationId, content: content);
}

class MarkConversationRead {
  const MarkConversationRead(this._repository);
  final ChatRepository _repository;
  Future<void> call(String conversationId) => _repository.markConversationRead(conversationId);
}
