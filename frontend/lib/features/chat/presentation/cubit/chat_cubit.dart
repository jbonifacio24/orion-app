import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/chat_entities.dart';
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
        failure: clearFailure ? null : failure ?? this.failure,
        loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
        actionFailure: clearActionFailure ? null : actionFailure ?? this.actionFailure,
      );
}

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._getMessages, this._sendMessage, this._markRead)
      : super(const ChatState());

  final GetMessages _getMessages;
  final SendMessage _sendMessage;
  final MarkConversationRead _markRead;
  int _generation = 0;

  Future<void> load(String conversationId) async {
    final requestId = ++_generation;
    emit(ChatState(conversationId: conversationId, isInitialLoading: true, pageSize: state.pageSize));
    await _loadPage(conversationId, 1, requestId, reset: true);
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
        items: _merge(reset ? const [] : state.items, result.items),
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
