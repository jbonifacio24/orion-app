import 'package:dio/dio.dart';

import '../../domain/entities/notification.dart';
import '../models/notification_models.dart';

class NotificationsDataSource {
  const NotificationsDataSource(this._dio);

  final Dio _dio;

  Future<PagedNotificationsModel> getNotifications({
    required int page,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'unreadOnly': unreadOnly,
        if (type != null && type != NotificationType.unknown) 'type': type.index,
      },
    );
    return PagedNotificationsModel.fromJson(response.data!);
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/notifications/unread-count');
    final count = response.data?['count'];
    if (count is! int) throw const FormatException('El contador de notificaciones no es válido.');
    return count;
  }

  Future<void> markAsRead(String id) => _dio.patch<void>('/api/notifications/$id/read');

  Future<void> markAllAsRead() => _dio.patch<void>('/api/notifications/read-all');
}
