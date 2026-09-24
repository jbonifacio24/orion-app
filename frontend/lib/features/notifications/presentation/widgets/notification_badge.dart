import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: 2,
      top: 2,
      child: Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.error, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(count > 99 ? '99+' : '$count', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onError)),
      ),
    );
  }
}
