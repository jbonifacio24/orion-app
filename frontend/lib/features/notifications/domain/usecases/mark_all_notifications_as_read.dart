import '../repositories/notifications_repository.dart';

class MarkAllNotificationsAsRead {
  const MarkAllNotificationsAsRead(this._repository);

  final NotificationsRepository _repository;

  Future<void> call() => _repository.markAllAsRead();
}
