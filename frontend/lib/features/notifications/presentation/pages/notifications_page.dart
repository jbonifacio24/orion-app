import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../domain/entities/notification.dart';
import '../cubit/notifications_cubit.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<NotificationsCubit>().state.page == 0) context.read<NotificationsCubit>().load();
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) context.read<NotificationsCubit>().loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationsCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppLocalizations.notifications),
        actions: [
          if (state.unreadCount > 0)
            IconButton(
              tooltip: AppLocalizations.markAllAsRead,
              onPressed: state.isUpdating ? null : context.read<NotificationsCubit>().markAllAsRead,
              icon: const Icon(Icons.done_all),
            ),
        ],
      ),
      body: Column(children: [
        if (state.actionFailure != null) _ActionFailure(message: state.actionFailure!),
        Expanded(child: _content(context, state)),
      ]),
    );
  }

  Widget _content(BuildContext context, NotificationsState state) {
    if (state.isInitialLoading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.failure != null && state.items.isEmpty) return _Failure(message: state.failure!, onRetry: context.read<NotificationsCubit>().load);
    if (state.items.isEmpty) return const Center(child: Text(AppLocalizations.noNotifications));
    return RefreshIndicator(
      onRefresh: context.read<NotificationsCubit>().refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        itemCount: state.items.length + (state.isLoadingMore || state.loadingMoreFailure != null ? 1 : 0),
        separatorBuilder: (_, index) => index < state.items.length - 1 ? const Divider(height: 1) : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index == state.items.length) return state.loadingMoreFailure != null ? _Failure(message: state.loadingMoreFailure!, onRetry: context.read<NotificationsCubit>().loadMore) : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          final item = state.items[index];
          return NotificationTile(notification: item, onTap: () => _openNotification(context, item));
        },
      ),
    );
  }

  Future<void> _openNotification(BuildContext context, AppNotification notification) async {
    final cubit = context.read<NotificationsCubit>();
    final router = GoRouter.of(context);
    if (!notification.isRead && !await cubit.markAsRead(notification.id)) return;
    if (!mounted) return;
    final target = notification.target;
    if (target == null) return;
    switch (target.resourceType) {
      case NotificationResourceType.theftReport:
        router.pushNamed(RouteNames.theftReportDetail, pathParameters: {'id': target.resourceId});
      case NotificationResourceType.product:
        router.pushNamed(RouteNames.marketplaceProductDetail, pathParameters: {'id': target.resourceId});
      case NotificationResourceType.workshop:
        router.pushNamed(RouteNames.workshopDetail, pathParameters: {'id': target.resourceId});
    }
  }
}

class _ActionFailure extends StatelessWidget {
  const _ActionFailure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(message), actions: [TextButton(onPressed: context.read<NotificationsCubit>().clearActionFailure, child: const Text(AppLocalizations.dismiss))]);
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry))])));
}
