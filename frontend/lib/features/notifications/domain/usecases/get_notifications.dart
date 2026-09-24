import '../entities/notification.dart';
import '../entities/paged_notifications.dart';
import '../repositories/notifications_repository.dart';

class GetNotifications {
  const GetNotifications(this._repository);

  final NotificationsRepository _repository;

  Future<PagedNotifications> call({
    required int page,
    int pageSize = 20,
    bool unreadOnly = false,
    NotificationType? type,
  }) => _repository.getNotifications(
        page: page,
        pageSize: pageSize,
        unreadOnly: unreadOnly,
        type: type,
      );
}
