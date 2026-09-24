import 'notification.dart';

class PagedNotifications {
  const PagedNotifications({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<AppNotification> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
