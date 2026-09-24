import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/get_unread_notification_count.dart';
import '../../domain/usecases/mark_all_notifications_as_read.dart';
import '../../domain/usecases/mark_notification_as_read.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalCount = 0,
    this.totalPages = 0,
    this.unreadCount = 0,
    this.unreadOnly = false,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isUpdating = false,
    this.failure,
    this.loadingMoreFailure,
    this.actionFailure,
  });

  final List<AppNotification> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final int unreadCount;
  final bool unreadOnly;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isUpdating;
  final String? failure;
  final String? loadingMoreFailure;
  final String? actionFailure;

  bool get hasMore => page < totalPages;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    int? unreadCount,
    bool? unreadOnly,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isUpdating,
    String? failure,
    bool clearFailure = false,
    String? loadingMoreFailure,
    bool clearLoadingMoreFailure = false,
    String? actionFailure,
    bool clearActionFailure = false,
  }) => NotificationsState(
        items: items ?? this.items,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        totalCount: totalCount ?? this.totalCount,
        totalPages: totalPages ?? this.totalPages,
        unreadCount: unreadCount ?? this.unreadCount,
        unreadOnly: unreadOnly ?? this.unreadOnly,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isUpdating: isUpdating ?? this.isUpdating,
        failure: clearFailure ? null : failure ?? this.failure,
        loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
        actionFailure: clearActionFailure ? null : actionFailure ?? this.actionFailure,
      );
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._getNotifications, this._getUnreadCount, this._markAsRead, this._markAllAsRead)
      : super(const NotificationsState());

  final GetNotifications _getNotifications;
  final GetUnreadNotificationCount _getUnreadCount;
  final MarkNotificationAsRead _markAsRead;
  final MarkAllNotificationsAsRead _markAllAsRead;
  int _generation = 0;

  Future<void> load() => _loadPage(1, reset: true);

  Future<void> loadUnreadCount() => _loadUnreadCount(++_generation);

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    await _loadPage(1, reset: true, refreshing: true);
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isRefreshing || state.isLoadingMore || !state.hasMore) return;
    await _loadPage(state.page + 1, reset: false);
  }

  Future<void> setUnreadOnly(bool value) async {
    if (state.unreadOnly == value) return;
    await _loadPage(1, reset: true, unreadOnly: value);
  }

  Future<void> _loadPage(int page, {required bool reset, bool refreshing = false, bool? unreadOnly}) async {
    final requestId = ++_generation;
    final activeUnreadOnly = unreadOnly ?? state.unreadOnly;
    if (reset) {
      emit(state.copyWith(unreadOnly: activeUnreadOnly, isInitialLoading: !refreshing, isRefreshing: refreshing, isLoadingMore: false, clearFailure: true, clearLoadingMoreFailure: true));
    } else {
      emit(state.copyWith(isLoadingMore: true, clearLoadingMoreFailure: true));
    }
    try {
      final result = await _getNotifications(page: page, pageSize: state.pageSize, unreadOnly: activeUnreadOnly);
      if (isClosed || requestId != _generation) return;
      final items = reset ? result.items : _merge(state.items, result.items);
      emit(state.copyWith(items: items, page: result.page, pageSize: result.pageSize, totalCount: result.totalCount, totalPages: result.totalPages, isInitialLoading: false, isRefreshing: false, isLoadingMore: false, clearFailure: true, clearLoadingMoreFailure: true));
      await _loadUnreadCount(requestId);
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      final message = ErrorMapper.from(error).message;
      if (reset) {
        emit(state.copyWith(isInitialLoading: false, isRefreshing: false, failure: message));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreFailure: message));
      }
    }
  }

  Future<void> _loadUnreadCount(int requestId) async {
    try {
      final count = await _getUnreadCount();
      if (!isClosed && requestId == _generation) emit(state.copyWith(unreadCount: count < 0 ? 0 : count));
    } catch (error) {
      if (!isClosed && requestId == _generation) emit(state.copyWith(actionFailure: ErrorMapper.from(error).message));
    }
  }

  Future<bool> markAsRead(String id) async {
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0 || state.items[index].isRead || state.isUpdating) return true;
    final requestGeneration = _generation;
    emit(state.copyWith(isUpdating: true, clearActionFailure: true));
    try {
      await _markAsRead(id);
      if (isClosed || requestGeneration != _generation) return false;
      final currentIndex = state.items.indexWhere((item) => item.id == id);
      if (currentIndex < 0) return true;
      final item = state.items[currentIndex];
      final items = [...state.items]..[currentIndex] = item.copyWith(isRead: true, readAt: DateTime.now().toUtc());
      emit(state.copyWith(items: items, unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0, isUpdating: false));
      return true;
    } catch (error) {
      if (!isClosed && requestGeneration == _generation) emit(state.copyWith(isUpdating: false, actionFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  Future<void> markAllAsRead() async {
    if (state.unreadCount == 0 || state.isUpdating) return;
    final requestGeneration = _generation;
    emit(state.copyWith(isUpdating: true, clearActionFailure: true));
    try {
      await _markAllAsRead();
      if (isClosed || requestGeneration != _generation) return;
      final readAt = DateTime.now().toUtc();
      emit(state.copyWith(items: state.items.map((item) => item.isRead ? item : item.copyWith(isRead: true, readAt: readAt)).toList(growable: false), unreadCount: 0, isUpdating: false));
    } catch (error) {
      if (!isClosed && requestGeneration == _generation) emit(state.copyWith(isUpdating: false, actionFailure: ErrorMapper.from(error).message));
    }
  }

  void clear() {
    _generation++;
    emit(const NotificationsState());
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));

  List<AppNotification> _merge(List<AppNotification> current, List<AppNotification> incoming) {
    final byId = {for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }
}
