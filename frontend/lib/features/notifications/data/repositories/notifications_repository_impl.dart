import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/paged_notifications.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl(this._dataSource);

  final NotificationsDataSource _dataSource;

  @override
  Future<PagedNotifications> getNotifications({
    required int page,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) => _map(() => _dataSource.getNotifications(page: page, pageSize: pageSize, unreadOnly: unreadOnly, type: type));

  @override
  Future<int> getUnreadCount() => _map(_dataSource.getUnreadCount);

  @override
  Future<void> markAsRead(String id) => _map(() => _dataSource.markAsRead(id));

  @override
  Future<void> markAllAsRead() => _map(_dataSource.markAllAsRead);

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
