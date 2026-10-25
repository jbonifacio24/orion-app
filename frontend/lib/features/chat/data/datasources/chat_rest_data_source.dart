import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../models/chat_models.dart';

class ChatRestDataSource {
  const ChatRestDataSource(this._dio);

  final Dio _dio;

  Future<List<ConversationModel>> getConversations() async {
    final response = await _dio.get<List<dynamic>>('/conversations');
    final data = response.data;
    if (data == null) throw const FormatException('La respuesta de conversaciones no es válida.');
    return data.map((item) {
      if (item is! Map<String, dynamic>) throw const FormatException('La respuesta contiene una conversación inválida.');
      return ConversationModel.fromJson(item);
    }).toList(growable: false);
  }

  Future<ConversationModel> getOrCreateDirectConversation(String recipientUserId) async {
    final response = await _dio.post<Map<String, dynamic>>('/conversations/direct', data: {'recipientUserId': recipientUserId});
    if (response.data == null) throw const FormatException('La conversación recibida no es válida.');
    return ConversationModel.fromJson(response.data!);
  }

  Future<PagedMessagesModel> getMessages({required String conversationId, required int page, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    if (response.data == null) throw const FormatException('La respuesta de mensajes no es válida.');
    return PagedMessagesModel.fromJson(response.data!);
  }

  Future<ChatMessageModel> sendMessage({required String conversationId, required String content}) async {
    final response = await _dio.post<Map<String, dynamic>>('/conversations/$conversationId/messages', data: {'content': content});
    if (response.data == null) throw const FormatException('El mensaje recibido no es válido.');
    return ChatMessageModel.fromJson(response.data!);
  }

  Future<ChatMessageModel> sendAttachment({required String conversationId, required PlatformFile file}) async {
    final bytes = file.bytes;
    if (bytes == null) throw const FormatException('No se pudo leer el archivo seleccionado.');
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/$conversationId/attachments',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: file.name, contentType: _contentType(file.name))}),
    );
    if (response.data == null) throw const FormatException('El adjunto recibido no es válido.');
    return ChatMessageModel.fromJson(response.data!);
  }

  MediaType _contentType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'mp3' => MediaType('audio', 'mpeg'),
      'ogg' => MediaType('audio', 'ogg'),
      'wav' => MediaType('audio', 'wav'),
      'webm' => MediaType('audio', 'webm'),
      _ => MediaType('application', 'octet-stream'),
    };
  }

  Future<void> markConversationRead(String conversationId) => _dio.patch<void>('/conversations/$conversationId/read');
}
