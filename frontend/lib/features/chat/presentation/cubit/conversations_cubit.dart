import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/usecases/chat_usecases.dart';

class ConversationsState {
  const ConversationsState({
    this.items = const [],
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isCreating = false,
    this.failure,
    this.actionFailure,
  });

  final List<Conversation> items;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isCreating;
  final String? failure;
  final String? actionFailure;

  ConversationsState copyWith({
    List<Conversation>? items,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isCreating,
    String? failure,
    bool clearFailure = false,
    String? actionFailure,
    bool clearActionFailure = false,
  }) => ConversationsState(
        items: items ?? this.items,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isCreating: isCreating ?? this.isCreating,
        failure: clearFailure ? null : failure ?? this.failure,
        actionFailure: clearActionFailure ? null : actionFailure ?? this.actionFailure,
      );
}

class ConversationsCubit extends Cubit<ConversationsState> {
  ConversationsCubit(this._getConversations, this._getOrCreateDirect)
      : super(const ConversationsState());

  final GetConversations _getConversations;
  final GetOrCreateDirectConversation _getOrCreateDirect;
  int _generation = 0;

  Future<void> load() async {
    if (state.isInitialLoading) return;
    final requestId = ++_generation;
    emit(state.copyWith(isInitialLoading: true, isRefreshing: false, clearFailure: true));
    try {
      final items = await _getConversations();
      if (isClosed || requestId != _generation) return;
      emit(state.copyWith(items: items, isInitialLoading: false, isRefreshing: false, clearFailure: true));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      emit(state.copyWith(isInitialLoading: false, isRefreshing: false, failure: ErrorMapper.from(error).message));
    }
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    final requestId = ++_generation;
    emit(state.copyWith(isRefreshing: true, clearFailure: true));
    try {
      final items = await _getConversations();
      if (isClosed || requestId != _generation) return;
      emit(state.copyWith(items: items, isRefreshing: false, isInitialLoading: false, clearFailure: true));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      emit(state.copyWith(isRefreshing: false, failure: ErrorMapper.from(error).message));
    }
  }

  Future<Conversation?> getOrCreateDirect(String recipientUserId) async {
    final normalized = recipientUserId.trim();
    if (normalized.isEmpty || state.isCreating) return null;
    final requestId = ++_generation;
    emit(state.copyWith(isCreating: true, clearActionFailure: true));
    try {
      final conversation = await _getOrCreateDirect(normalized);
      if (isClosed || requestId != _generation) return null;
      emit(state.copyWith(items: _replaceConversation(state.items, conversation), isCreating: false));
      return conversation;
    } catch (error) {
      if (!isClosed && requestId == _generation) {
        emit(state.copyWith(isCreating: false, actionFailure: ErrorMapper.from(error).message));
      }
      return null;
    }
  }

  void markConversationReadLocally(String conversationId) {
    final index = state.items.indexWhere((item) => item.id == conversationId);
    if (index < 0) return;
    final current = state.items[index];
    final updated = Conversation(
      id: current.id,
      type: current.type,
      createdAt: current.createdAt,
      lastMessageAt: current.lastMessageAt,
      participant: current.participant,
      lastMessage: current.lastMessage,
      unreadCount: 0,
    );
    final items = [...state.items]..[index] = updated;
    emit(state.copyWith(items: items));
  }

  void clear() {
    _generation++;
    emit(const ConversationsState());
  }

  void clearActionFailure() => emit(state.copyWith(clearActionFailure: true));

  List<Conversation> _replaceConversation(List<Conversation> items, Conversation conversation) {
    final byId = {for (final item in items) item.id: item};
    byId[conversation.id] = conversation;
    return byId.values.toList(growable: false);
  }
}
