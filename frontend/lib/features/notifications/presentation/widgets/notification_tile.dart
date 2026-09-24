import 'package:flutter/material.dart';

import '../../domain/entities/notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({required this.notification, required this.onTap, super.key});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: notification.title,
      child: ListTile(
        onTap: onTap,
        leading: Icon(_icon(notification.type), color: notification.isRead ? null : theme.colorScheme.primary),
        title: Text(notification.title, style: notification.isRead ? null : const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(notification.body),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(_formatDate(notification.createdAt), style: theme.textTheme.labelSmall),
          if (!notification.isRead) ...[const SizedBox(height: 4), CircleAvatar(radius: 4, backgroundColor: theme.colorScheme.primary)],
        ]),
      ),
    );
  }

  IconData _icon(NotificationType type) => switch (type) {
        NotificationType.system => Icons.notifications_outlined,
        NotificationType.security => Icons.security_outlined,
        NotificationType.message => Icons.chat_bubble_outline,
        NotificationType.social => Icons.people_outline,
        NotificationType.marketplace => Icons.storefront_outlined,
        NotificationType.theft => Icons.warning_amber_rounded,
        NotificationType.unknown => Icons.notifications_none,
      };

  String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
}
