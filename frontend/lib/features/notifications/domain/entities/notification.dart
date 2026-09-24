enum NotificationType {
  system,
  security,
  message,
  social,
  marketplace,
  theft,
  unknown,
}

enum NotificationResourceType {
  theftReport,
  product,
  workshop,
}

class NotificationTarget {
  const NotificationTarget({required this.resourceType, required this.resourceId});

  final NotificationResourceType resourceType;
  final String resourceId;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
    required this.target,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final NotificationTarget? target;

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
        target: target,
      );
}
