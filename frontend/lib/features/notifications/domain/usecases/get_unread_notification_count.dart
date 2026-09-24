import '../repositories/notifications_repository.dart';

class GetUnreadNotificationCount {
  const GetUnreadNotificationCount(this._repository);

  final NotificationsRepository _repository;

  Future<int> call() => _repository.getUnreadCount();
}
