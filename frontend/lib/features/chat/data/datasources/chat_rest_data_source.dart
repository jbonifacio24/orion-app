import 'package:dio/dio.dart';

import '../models/chat_models.dart';

class ChatRestDataSource {
  const ChatRestDataSource(this._dio);

  final Dio _dio;

  Future<List<ConversationModel>> getConversations() async {
    final response = await _dio.get<List<dynamic>>('/api/conversations');
    final data = response.data;
    if (data == null) throw const FormatException('La respuesta de conversaciones no es válida.');
    return data.map((item) {
      if (item is! Map<String, dynamic>) throw const FormatException('La respuesta contiene una conversación inválida.');
      return ConversationModel.fromJson(item);
    }).toList(growable: false);
  }

  Future<ConversationModel> getOrCreateDirectConversation(String recipientUserId) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/conversations/direct', data: {'recipientUserId': recipientUserId});
    if (response.data == null) throw const FormatException('La conversación recibida no es válida.');
    return ConversationModel.fromJson(response.data!);
  }

  Future<PagedMessagesModel> getMessages({required String conversationId, required int page, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    if (response.data == null) throw const FormatException('La respuesta de mensajes no es válida.');
    return PagedMessagesModel.fromJson(response.data!);
  }

  Future<ChatMessageModel> sendMessage({required String conversationId, required String content}) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/conversations/$conversationId/messages', data: {'content': content});
    if (response.data == null) throw const FormatException('El mensaje recibido no es válido.');
    return ChatMessageModel.fromJson(response.data!);
  }

  Future<void> markConversationRead(String conversationId) => _dio.patch<void>('/api/conversations/$conversationId/read');
}
