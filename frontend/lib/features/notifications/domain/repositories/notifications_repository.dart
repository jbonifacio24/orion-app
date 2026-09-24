import '../entities/notification.dart';
import '../entities/paged_notifications.dart';

abstract interface class NotificationsRepository {
  Future<PagedNotifications> getNotifications({
    required int page,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String id);

  Future<void> markAllAsRead();
}
