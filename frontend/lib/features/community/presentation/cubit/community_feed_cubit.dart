import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_events.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/usecases/create_community_post.dart';
import '../../domain/usecases/delete_community_post.dart';
import '../../domain/usecases/get_community_feed.dart';
import 'community_feed_state.dart';

class CommunityFeedCubit extends Cubit<CommunityFeedState> {
  CommunityFeedCubit(
    this._getCommunityFeed,
    this._createCommunityPost,
    this._deleteCommunityPost, [
    SessionEvents? sessionEvents,
  ]) : super(const CommunityFeedState()) {
    _sessionSubscription = sessionEvents?.onInvalidated.listen((_) => _invalidateRequests());
  }

  static const pageSize = 20;
  static const maxContentLength = 5000;

  final GetCommunityFeed _getCommunityFeed;
  final CreateCommunityPost _createCommunityPost;
  final DeleteCommunityPost _deleteCommunityPost;
  StreamSubscription<void>? _sessionSubscription;
  int _generation = 0;
  int _createOperationToken = 0;
  int _deleteOperationToken = 0;
  int _loadOperationToken = 0;

  Future<void> loadInitial() => _loadPage(1, reset: true);

  Future<void> refresh() {
    if (state.isRefreshing) return Future.value();
    return _loadPage(1, reset: true, refreshing: true);
  }

  Future<void> retry() => _loadPage(1, reset: true);

  Future<void> loadMore() {
    if (state.page == 0 || !state.hasMore || state.isInitialLoading || state.isRefreshing || state.isLoadingMore) {
      return Future.value();
    }
    return _loadPage(state.page + 1, reset: false);
  }

  Future<void> retryLoadMore() {
    if (state.page == 0 || !state.hasMore || state.isLoadingMore) return Future.value();
    return _loadPage(state.page + 1, reset: false);
  }

  Future<CommunityPost?> createPost(String rawContent) async {
    if (state.isSubmitting) return null;
    final content = rawContent.trim();
    if (content.isEmpty) {
      emit(state.copyWith(operationFailure: 'El contenido es obligatorio.'));
      return null;
    }
    if (content.length > maxContentLength) {
      emit(state.copyWith(operationFailure: 'El contenido debe tener como máximo 5000 caracteres.'));
      return null;
    }

    final requestGeneration = ++_generation;
    final operationToken = ++_createOperationToken;
    emit(state.copyWith(isSubmitting: true, clearOperationFailure: true));
    try {
      final post = await _createCommunityPost(content);
      if (isClosed) return null;
      if (requestGeneration != _generation) {
        if (_createOperationToken == operationToken && state.isSubmitting) emit(state.copyWith(isSubmitting: false));
        return null;
      }
      final alreadyPresent = state.items.any((item) => item.id == post.id);
      emit(state.copyWith(
        items: alreadyPresent ? state.items : _insertPost(state.items, post),
        totalCount: alreadyPresent ? state.totalCount : state.totalCount + 1,
        isSubmitting: false,
        clearOperationFailure: true,
      ));
      return post;
    } catch (error) {
      if (isClosed) return null;
      if (requestGeneration != _generation) {
        if (_createOperationToken == operationToken && state.isSubmitting) emit(state.copyWith(isSubmitting: false));
        return null;
      }
      emit(state.copyWith(isSubmitting: false, operationFailure: ErrorMapper.from(error).message));
      return null;
    }
  }

  Future<bool> deletePost(String postId) async {
    if (state.deletingPostId != null) return false;
    final requestGeneration = ++_generation;
    final operationToken = ++_deleteOperationToken;
    emit(state.copyWith(deletingPostId: postId, clearOperationFailure: true));
    try {
      await _deleteCommunityPost(postId);
      if (isClosed) return false;
      if (requestGeneration != _generation) {
        if (_deleteOperationToken == operationToken && state.deletingPostId == postId) emit(state.copyWith(clearDeletingPostId: true));
        return false;
      }
      final items = state.items.where((item) => item.id != postId).toList(growable: false);
      emit(state.copyWith(
        items: items,
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
        clearDeletingPostId: true,
        clearOperationFailure: true,
      ));
      return true;
    } catch (error) {
      if (isClosed) return false;
      if (requestGeneration != _generation) {
        if (_deleteOperationToken == operationToken && state.deletingPostId == postId) emit(state.copyWith(clearDeletingPostId: true));
        return false;
      }
      emit(state.copyWith(clearDeletingPostId: true, operationFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  void insertCreatedPost(CommunityPost post) {
    if (isClosed || state.items.any((item) => item.id == post.id)) return;
    emit(state.copyWith(
      items: _insertPost(state.items, post),
      totalCount: state.totalCount + 1,
      clearOperationFailure: true,
    ));
  }

  void clearOperationFailure() {
    if (!isClosed) emit(state.copyWith(clearOperationFailure: true));
  }

  Future<void> _loadPage(int page, {required bool reset, bool refreshing = false}) async {
    final requestGeneration = ++_generation;
    final operationToken = ++_loadOperationToken;
    if (reset) {
      emit(state.copyWith(
        isInitialLoading: !refreshing && state.items.isEmpty,
        isRefreshing: refreshing,
        isLoadingMore: false,
        clearFailure: true,
        clearLoadingMoreFailure: true,
      ));
    } else {
      emit(state.copyWith(isLoadingMore: true, clearLoadingMoreFailure: true));
    }

    try {
      final result = await _getCommunityFeed(page: page, pageSize: pageSize);
      if (isClosed) return;
      if (requestGeneration != _generation) {
        if (_loadOperationToken == operationToken) {
          emit(state.copyWith(isInitialLoading: false, isRefreshing: false, isLoadingMore: false));
        }
        return;
      }
      final items = reset ? _deduplicate(result.items) : _merge(state.items, result.items);
      emit(state.copyWith(
        items: items,
        page: result.page,
        totalPages: result.totalPages,
        totalCount: result.totalCount,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        clearFailure: true,
        clearLoadingMoreFailure: true,
      ));
    } catch (error) {
      if (isClosed) return;
      if (requestGeneration != _generation) {
        if (_loadOperationToken == operationToken) {
          emit(state.copyWith(isInitialLoading: false, isRefreshing: false, isLoadingMore: false));
        }
        return;
      }
      final message = ErrorMapper.from(error).message;
      if (reset) {
        emit(state.copyWith(isInitialLoading: false, isRefreshing: false, failure: message));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreFailure: message));
      }
    }
  }

  List<CommunityPost> _merge(List<CommunityPost> current, List<CommunityPost> incoming) {
    final byId = <String, CommunityPost>{for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  List<CommunityPost> _deduplicate(List<CommunityPost> items) {
    final byId = <String, CommunityPost>{};
    for (final item in items) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  List<CommunityPost> _insertPost(List<CommunityPost> current, CommunityPost post) {
    final items = [...current, post];
    items.sort((a, b) {
      final aDate = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateOrder = bDate.compareTo(aDate);
      return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
    });
    return items.toList(growable: false);
  }

  void _invalidateRequests() {
    _generation++;
    if (!isClosed) emit(state.copyWith(isInitialLoading: false, isRefreshing: false, isLoadingMore: false, isSubmitting: false, clearDeletingPostId: true));
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
