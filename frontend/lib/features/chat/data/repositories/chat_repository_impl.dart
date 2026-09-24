import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_rest_data_source.dart';

class ChatRepositoryImpl implements ChatRepository {
  const ChatRepositoryImpl(this._dataSource);

  final ChatRestDataSource _dataSource;

  @override
  Future<List<Conversation>> getConversations() => _map(_dataSource.getConversations);

  @override
  Future<Conversation> getOrCreateDirectConversation(String recipientUserId) => _map(() => _dataSource.getOrCreateDirectConversation(recipientUserId));

  @override
  Future<PagedMessages> getMessages({required String conversationId, required int page, int pageSize = 20}) => _map(() => _dataSource.getMessages(conversationId: conversationId, page: page, pageSize: pageSize));

  @override
  Future<ChatMessage> sendMessage({required String conversationId, required String content}) => _map(() => _dataSource.sendMessage(conversationId: conversationId, content: content));

  @override
  Future<void> markConversationRead(String conversationId) => _map(() => _dataSource.markConversationRead(conversationId));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
