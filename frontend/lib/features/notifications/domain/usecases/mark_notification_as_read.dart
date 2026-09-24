import '../repositories/notifications_repository.dart';

class MarkNotificationAsRead {
  const MarkNotificationAsRead(this._repository);

  final NotificationsRepository _repository;

  Future<void> call(String id) => _repository.markAsRead(id);
}
