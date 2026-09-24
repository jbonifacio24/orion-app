import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_realtime_repository.dart';
import '../../domain/usecases/chat_usecases.dart';

class ChatState {
  const ChatState({
    this.conversationId,
    this.items = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalCount = 0,
    this.totalPages = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.isMarkingRead = false,
    this.realtimeState = ChatRealtimeConnectionState.disconnected,
    this.failure,
    this.loadingMoreFailure,
    this.actionFailure,
  });

  final String? conversationId;
  final List<ChatMessage> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isSending;
  final bool isMarkingRead;
  final ChatRealtimeConnectionState realtimeState;
  final String? failure;
  final String? loadingMoreFailure;
  final String? actionFailure;

  bool get hasMore => page < totalPages;

  ChatState copyWith({
    String? conversationId,
    bool clearConversationId = false,
    List<ChatMessage>? items,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isSending,
    bool? isMarkingRead,
    ChatRealtimeConnectionState? realtimeState,
    String? failure,
    bool clearFailure = false,
    String? loadingMoreFailure,
    bool clearLoadingMoreFailure = false,
    String? actionFailure,
    bool clearActionFailure = false,
  }) => ChatState(
        conversationId: clearConversationId ? null : conversationId ?? this.conversationId,
        items: items ?? this.items,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        totalCount: totalCount ?? this.totalCount,
        totalPages: totalPages ?? this.totalPages,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isSending: isSending ?? this.isSending,
        isMarkingRead: isMarkingRead ?? this.isMarkingRead,
        realtimeState: realtimeState ?? this.realtimeState,
        failure: clearFailure ? null : failure ?? this.failure,
        loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
        actionFailure: clearActionFailure ? null : actionFailure ?? this.actionFailure,
      );
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._getMessages, this._sendMessage, this._markRead, [this._realtime])
      : super(const ChatState()) {
    _messageSubscription = _realtime?.messages.listen(_onRealtimeMessage);
    _connectionSubscription = _realtime?.connectionStates.listen(_onConnectionState);
  }

  final GetMessages _getMessages;
  final SendMessage _sendMessage;
  final MarkConversationRead _markRead;
  final ChatRealtimeRepository? _realtime;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatRealtimeConnectionState>? _connectionSubscription;
  Future<void>? _joiningFuture;
  String? _joiningConversation;
  String? _joinedConversation;
  bool _hasConnected = false;
  int _generation = 0;

  Future<void> load(String conversationId) async {
    final requestId = ++_generation;
    emit(ChatState(conversationId: conversationId, isInitialLoading: true, pageSize: state.pageSize));
    await _loadPage(conversationId, 1, requestId, reset: true);
    if (!isClosed && requestId == _generation && state.conversationId == conversationId) {
      await _activateRealtime(conversationId);
    }
  }

  Future<void> _activateRealtime(String conversationId) async {
    final realtime = _realtime;
    if (realtime == null) return;
    try {
      await realtime.start();
      if (!isClosed && state.conversationId == conversationId) await _join(conversationId);
    } catch (_) {
      // REST chat remains usable while realtime is unavailable.
    }
  }

  Future<void> _join(String conversationId) async {
    final realtime = _realtime;
    if (realtime == null || _joinedConversation == conversationId) return;
    if (_joiningConversation == conversationId && _joiningFuture != null) {
      await _joiningFuture;
      return;
    }
    _joiningConversation = conversationId;
    final future = realtime.joinConversation(conversationId);
    _joiningFuture = future;
    try {
      await future;
      if (!isClosed && state.conversationId == conversationId) _joinedConversation = conversationId;
    } finally {
      if (identical(_joiningFuture, future)) {
        _joiningFuture = null;
        _joiningConversation = null;
      }
    }
  }

  void _onRealtimeMessage(ChatMessage message) {
    if (isClosed || state.conversationId != message.conversationId) return;
    emit(state.copyWith(items: _merge(state.items, [message])));
  }

  void _onConnectionState(ChatRealtimeConnectionState connectionState) {
    if (isClosed) return;
    emit(state.copyWith(realtimeState: connectionState));
    if (connectionState == ChatRealtimeConnectionState.reconnecting ||
        connectionState == ChatRealtimeConnectionState.disconnected ||
        connectionState == ChatRealtimeConnectionState.failed) {
      _joinedConversation = null;
      return;
    }
    if (connectionState != ChatRealtimeConnectionState.connected) return;
    final conversationId = state.conversationId;
    if (conversationId == null) return;
    final shouldResync = _hasConnected;
    _hasConnected = true;
    unawaited(_rejoinAndResync(conversationId, shouldResync));
  }

  Future<void> _rejoinAndResync(String conversationId, bool shouldResync) async {
    try {
      await _join(conversationId);
      if (shouldResync && !isClosed && state.conversationId == conversationId) await refresh();
    } catch (_) {
      // A failed rejoin will be retried by the next connection transition.
    }
  }

  Future<void> refresh() async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.isRefreshing) return;
    final requestId = ++_generation;
    emit(state.copyWith(isRefreshing: true, clearFailure: true));
    await _loadPage(conversationId, 1, requestId, reset: true);
  }

  Future<void> loadOlder() async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.isInitialLoading || state.isRefreshing || state.isLoadingMore || !state.hasMore) return;
    final requestId = _generation;
    emit(state.copyWith(isLoadingMore: true, clearLoadingMoreFailure: true));
    await _loadPage(conversationId, state.page + 1, requestId, reset: false);
  }

  Future<void> _loadPage(String conversationId, int page, int requestId, {required bool reset}) async {
    try {
      final result = await _getMessages(conversationId: conversationId, page: page, pageSize: state.pageSize);
      if (isClosed || requestId != _generation || state.conversationId != conversationId) return;
      emit(state.copyWith(
        items: _merge(state.items, result.items),
        conversationId: conversationId,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        clearFailure: true,
        clearLoadingMoreFailure: true,
      ));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      if (reset) {
        emit(state.copyWith(isInitialLoading: false, isRefreshing: false, failure: ErrorMapper.from(error).message));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreFailure: ErrorMapper.from(error).message));
      }
    }
  }

  Future<bool> send(String content) async {
    final normalized = content.trim();
    final conversationId = state.conversationId;
    if (conversationId == null || normalized.isEmpty || normalized.length > 10000 || state.isSending) return false;
    final requestId = _generation;
    emit(state.copyWith(isSending: true, clearActionFailure: true));
    try {
      final message = await _sendMessage(conversationId: conversationId, content: normalized);
      if (isClosed || requestId != _generation || state.conversationId != conversationId) return false;
      emit(state.copyWith(items: _merge(state.items, [message]), isSending: false));
      return true;
    } catch (error) {
      if (!isClosed && requestId == _generation) emit(state.copyWith(isSending: false, actionFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  Future<bool> markRead() async {
    final conversationId = state.conversationId;
    if (conversationId == null || state.isMarkingRead) return false;
    final requestId = _generation;
    emit(state.copyWith(isMarkingRead: true));
    try {
      await _markRead(conversationId);
      if (isClosed || requestId != _generation || state.conversationId != conversationId) return false;
      emit(state.copyWith(isMarkingRead: false));
      return true;
    } catch (error) {
      if (!isClosed && requestId == _generation) emit(state.copyWith(isMarkingRead: false, actionFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  void receiveMessage(ChatMessage message) {
    if (state.conversationId == message.conversationId) emit(state.copyWith(items: _merge(state.items, [message])));
  }

  void clear() {
    _generation++;
    emit(const ChatState());
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    await _connectionSubscription?.cancel();
    final conversationId = state.conversationId;
    if (_realtime != null && conversationId != null) {
      try {
        await _realtime.leaveConversation(conversationId);
      } catch (_) {}
    }
    return super.close();
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));

  List<ChatMessage> _merge(Iterable<ChatMessage> current, Iterable<ChatMessage> incoming) {
    final byId = {for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    final result = byId.values.toList(growable: false);
    result.sort((a, b) {
      final dateOrder = a.sentAt.compareTo(b.sentAt);
      return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
    });
    return result;
  }
}
