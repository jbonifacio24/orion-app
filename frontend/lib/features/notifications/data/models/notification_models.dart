import '../../../../core/error/app_failure.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/paged_notifications.dart';

NotificationType _notificationType(Object? value) {
  final index = value is int ? value : int.tryParse(value?.toString() ?? '');
  return switch (index) {
    0 => NotificationType.system,
    1 => NotificationType.security,
    2 => NotificationType.message,
    3 => NotificationType.social,
    4 => NotificationType.marketplace,
    5 => NotificationType.theft,
    _ => switch (value?.toString().toLowerCase()) {
        'system' => NotificationType.system,
        'security' => NotificationType.security,
        'message' => NotificationType.message,
        'social' => NotificationType.social,
        'marketplace' => NotificationType.marketplace,
        'theft' => NotificationType.theft,
        _ => NotificationType.unknown,
      },
  };
}

NotificationResourceType? _resourceType(Object? value) => switch (value) {
      'TheftReport' => NotificationResourceType.theftReport,
      'Product' => NotificationResourceType.product,
      'Workshop' => NotificationResourceType.workshop,
      _ => null,
    };

NotificationTarget? _target(Object? value) {
  if (value is! Map<String, dynamic>) return null;
  final resourceType = _resourceType(value['resourceType']);
  final resourceId = value['resourceId'] as String?;
  if (resourceType == null || resourceId == null || resourceId.isEmpty) return null;
  final parsedId = _tryGuid(resourceId);
  return parsedId == null ? null : NotificationTarget(resourceType: resourceType, resourceId: parsedId);
}

String? _tryGuid(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  final pattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
  return pattern.hasMatch(normalized) && normalized != '00000000-0000-0000-0000-000000000000' ? normalized : null;
}

DateTime _date(Object? value) => DateTime.tryParse(value is String ? value : '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.type,
    required super.title,
    required super.body,
    required super.isRead,
    required super.readAt,
    required super.createdAt,
    required super.target,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const SerializationFailure('La notificación no tiene un identificador válido.');
    }
    return NotificationModel(
      id: id,
      type: _notificationType(json['type']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] is String ? DateTime.tryParse(json['readAt'] as String) : null,
      createdAt: _date(json['createdAt']),
      target: _target(json['target']),
    );
  }
}

class PagedNotificationsModel extends PagedNotifications {
  const PagedNotificationsModel({
    required super.items,
    required super.page,
    required super.pageSize,
    required super.totalCount,
    required super.totalPages,
  });

  factory PagedNotificationsModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const SerializationFailure('La respuesta de notificaciones no tiene una lista válida.');
    }
    return PagedNotificationsModel(
      items: rawItems.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const SerializationFailure('La respuesta contiene una notificación inválida.');
        }
        return NotificationModel.fromJson(item);
      }).toList(growable: false),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
