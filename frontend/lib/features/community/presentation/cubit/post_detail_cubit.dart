import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_events.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/community_comment.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/usecases/create_community_comment.dart';
import '../../domain/usecases/delete_community_comment.dart';
import '../../domain/usecases/get_community_comments.dart';
import '../../domain/usecases/get_community_post.dart';
import '../../domain/usecases/like_community_post.dart';
import '../../domain/usecases/unlike_community_post.dart';
import 'post_detail_state.dart';

class PostDetailCubit extends Cubit<PostDetailState> {
  PostDetailCubit(
    this._getPost,
    this._getComments,
    this._likePost,
    this._unlikePost,
    this._createComment,
    this._deleteComment,
    [
    SessionEvents? sessionEvents,
  ]) : super(const PostDetailState()) {
    _sessionSubscription = sessionEvents?.onInvalidated.listen((_) => _invalidateRequests());
  }

  static const pageSize = 20;
  static const maxCommentLength = 2000;

  final GetCommunityPost _getPost;
  final GetCommunityComments _getComments;
  final LikeCommunityPost _likePost;
  final UnlikeCommunityPost _unlikePost;
  final CreateCommunityComment _createComment;
  final DeleteCommunityComment _deleteComment;
  StreamSubscription<void>? _sessionSubscription;
  String? _currentPostId;
  int _generation = 0;
  int _postLoadToken = 0;
  int _commentsLoadToken = 0;
  int _likeToken = 0;
  int _createCommentToken = 0;
  int _deleteCommentToken = 0;
  int? _failedCommentsPage;

  Future<void> load(String postId) async {
    if (isClosed) return;
    final generation = ++_generation;
    _currentPostId = postId;
    _failedCommentsPage = null;
    emit(const PostDetailState(isPostLoading: true, isCommentsLoading: true));
    await Future.wait([
      _loadPost(postId, generation),
      _loadComments(postId: postId, page: 1, reset: true, generation: generation),
    ]);
  }

  Future<void> refresh() async {
    final postId = _currentPostId;
    if (postId == null) return;
    await load(postId);
  }

  Future<void> retryPost() async {
    final postId = _currentPostId;
    if (postId == null) return;
    final generation = ++_generation;
    await _loadPost(postId, generation);
  }

  Future<void> retryComments() async {
    final postId = _currentPostId;
    if (postId == null || state.isCommentsLoading || state.isLoadingMoreComments) return;
    final failedPage = _failedCommentsPage;
    final generation = ++_generation;
    await _loadComments(
      postId: postId,
      page: failedPage ?? 1,
      reset: failedPage == null,
      generation: generation,
    );
  }

  Future<void> loadMoreComments() async {
    final postId = _currentPostId;
    if (postId == null || state.isCommentsLoading || state.isLoadingMoreComments || !state.hasMoreComments) return;
    final generation = ++_generation;
    await _loadComments(postId: postId, page: state.page + 1, reset: false, generation: generation);
  }

  Future<bool> like() => _setLike(true);

  Future<bool> unlike() => _setLike(false);

  Future<bool> toggleLike() => state.post?.likedByCurrentUser == true ? unlike() : like();

  Future<CommunityComment?> createComment(String rawContent) async {
    if (state.isCommentSubmitting || _currentPostId == null) return null;
    final content = rawContent.trim();
    if (content.isEmpty) {
      emit(state.copyWith(operationFailure: 'El comentario es obligatorio.'));
      return null;
    }
    if (content.length > maxCommentLength) {
      emit(state.copyWith(operationFailure: 'El comentario debe tener como máximo 2000 caracteres.'));
      return null;
    }

    final postId = _currentPostId!;
    final generation = ++_generation;
    final operationToken = ++_createCommentToken;
    emit(state.copyWith(isCommentSubmitting: true, clearOperationFailure: true));
    try {
      final comment = await _createComment(postId: postId, content: content);
      if (isClosed) return null;
      if (generation != _generation) {
        _clearCreateFlagIfOwned(operationToken);
        return null;
      }

      CommunityPost? refreshedPost;
      String? syncFailure;
      try {
        refreshedPost = await _getPost(postId);
      } catch (error) {
        syncFailure = ErrorMapper.from(error).message;
      }
      if (isClosed) return null;
      if (generation != _generation) {
        _clearCreateFlagIfOwned(operationToken);
        return null;
      }

      final currentPost = state.post;
      if (currentPost == null) {
        _clearCreateFlagIfOwned(operationToken);
        return null;
      }
      emit(state.copyWith(
        post: refreshedPost ?? currentPost.copyWith(commentCount: currentPost.commentCount + 1),
        comments: _insertComment(state.comments, comment),
        totalCount: state.totalCount + 1,
        isCommentSubmitting: false,
        operationFailure: syncFailure,
        clearOperationFailure: syncFailure == null,
      ));
      return comment;
    } catch (error) {
      if (isClosed) return null;
      if (generation != _generation) {
        _clearCreateFlagIfOwned(operationToken);
        return null;
      }
      emit(state.copyWith(isCommentSubmitting: false, operationFailure: ErrorMapper.from(error).message));
      return null;
    }
  }

  Future<bool> deleteComment(CommunityComment comment) async {
    if (!comment.isOwner || state.deletingCommentId != null || _currentPostId == null) return false;

    final postId = _currentPostId!;
    final generation = ++_generation;
    final operationToken = ++_deleteCommentToken;
    emit(state.copyWith(deletingCommentId: comment.id, clearOperationFailure: true));
    try {
      await _deleteComment(postId: postId, commentId: comment.id);
      if (isClosed) return false;
      if (generation != _generation) {
        _clearDeleteFlagIfOwned(operationToken, comment.id);
        return false;
      }

      CommunityPost? refreshedPost;
      String? syncFailure;
      try {
        refreshedPost = await _getPost(postId);
      } catch (error) {
        syncFailure = ErrorMapper.from(error).message;
      }
      if (isClosed) return false;
      if (generation != _generation) {
        _clearDeleteFlagIfOwned(operationToken, comment.id);
        return false;
      }

      final currentPost = state.post;
      emit(state.copyWith(
        post: refreshedPost ?? currentPost?.copyWith(commentCount: currentPost.commentCount > 0 ? currentPost.commentCount - 1 : 0),
        comments: state.comments.where((item) => item.id != comment.id).toList(growable: false),
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
        clearDeletingCommentId: true,
        operationFailure: syncFailure,
        clearOperationFailure: syncFailure == null,
      ));
      return true;
    } catch (error) {
      if (isClosed) return false;
      if (generation != _generation) {
        _clearDeleteFlagIfOwned(operationToken, comment.id);
        return false;
      }
      emit(state.copyWith(clearDeletingCommentId: true, operationFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  Future<void> _loadPost(String postId, int generation) async {
    final operationToken = ++_postLoadToken;
    try {
      final post = await _getPost(postId);
      if (isClosed) return;
      if (generation != _generation) {
        if (_postLoadToken == operationToken) emit(state.copyWith(isPostLoading: false));
        return;
      }
      emit(state.copyWith(post: post, isPostLoading: false, clearPostFailure: true));
    } catch (error) {
      if (isClosed) return;
      if (generation != _generation) {
        if (_postLoadToken == operationToken) emit(state.copyWith(isPostLoading: false));
        return;
      }
      emit(state.copyWith(isPostLoading: false, postFailure: ErrorMapper.from(error).message));
    }
  }

  Future<void> _loadComments({required String postId, required int page, required bool reset, required int generation}) async {
    final operationToken = ++_commentsLoadToken;
    emit(state.copyWith(
      isCommentsLoading: reset,
      isLoadingMoreComments: !reset,
      clearCommentsFailure: true,
    ));
    try {
      final result = await _getComments(postId: postId, page: page, pageSize: pageSize);
      if (isClosed) return;
      if (generation != _generation) {
        if (_commentsLoadToken == operationToken) {
          emit(state.copyWith(isCommentsLoading: false, isLoadingMoreComments: false));
        }
        return;
      }
      emit(state.copyWith(
        comments: reset ? _deduplicateComments(result.items) : _mergeComments(state.comments, result.items),
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        isCommentsLoading: false,
        isLoadingMoreComments: false,
        clearCommentsFailure: true,
      ));
      _failedCommentsPage = null;
    } catch (error) {
      if (isClosed) return;
      if (generation != _generation) {
        if (_commentsLoadToken == operationToken) {
          emit(state.copyWith(isCommentsLoading: false, isLoadingMoreComments: false));
        }
        return;
      }
      if (reset) {
        _failedCommentsPage = null;
        emit(state.copyWith(isCommentsLoading: false, commentsFailure: ErrorMapper.from(error).message));
      } else {
        _failedCommentsPage = page;
        emit(state.copyWith(isLoadingMoreComments: false, commentsFailure: ErrorMapper.from(error).message));
      }
    }
  }

  Future<bool> _setLike(bool liked) async {
    final post = state.post;
    if (post == null || state.isLikeProcessing) return false;
    final postId = post.id;
    final generation = ++_generation;
    final operationToken = ++_likeToken;
    emit(state.copyWith(isLikeProcessing: true, clearOperationFailure: true));
    try {
      final result = liked ? await _likePost(postId) : await _unlikePost(postId);
      if (isClosed) return false;
      if (generation != _generation) {
        _clearLikeFlagIfOwned(operationToken);
        return false;
      }
      final currentPost = state.post;
      if (currentPost == null) {
        _clearLikeFlagIfOwned(operationToken);
        return false;
      }
      emit(state.copyWith(
        post: currentPost.copyWith(
          likedByCurrentUser: result.likedByCurrentUser,
          likeCount: result.likeCount < 0 ? 0 : result.likeCount,
        ),
        isLikeProcessing: false,
        clearOperationFailure: true,
      ));
      return true;
    } catch (error) {
      if (isClosed) return false;
      if (generation != _generation) {
        _clearLikeFlagIfOwned(operationToken);
        return false;
      }
      emit(state.copyWith(isLikeProcessing: false, operationFailure: ErrorMapper.from(error).message));
      return false;
    }
  }

  void _clearCreateFlagIfOwned(int operationToken) {
    if (_createCommentToken == operationToken && state.isCommentSubmitting) {
      emit(state.copyWith(isCommentSubmitting: false));
    }
  }

  void _clearDeleteFlagIfOwned(int operationToken, String commentId) {
    if (_deleteCommentToken == operationToken && state.deletingCommentId == commentId) {
      emit(state.copyWith(clearDeletingCommentId: true));
    }
  }

  void _clearLikeFlagIfOwned(int operationToken) {
    if (_likeToken == operationToken && state.isLikeProcessing) {
      emit(state.copyWith(isLikeProcessing: false));
    }
  }

  List<CommunityComment> _deduplicateComments(List<CommunityComment> comments) {
    final byId = <String, CommunityComment>{};
    for (final comment in comments) {
      byId[comment.id] = comment;
    }
    return byId.values.toList(growable: false);
  }

  List<CommunityComment> _mergeComments(List<CommunityComment> current, List<CommunityComment> incoming) {
    final byId = <String, CommunityComment>{for (final comment in current) comment.id: comment};
    for (final comment in incoming) {
      byId[comment.id] = comment;
    }
    return byId.values.toList(growable: false);
  }

  List<CommunityComment> _insertComment(List<CommunityComment> current, CommunityComment comment) {
    if (current.any((item) => item.id == comment.id)) return current;
    final comments = [...current, comment];
    comments.sort((a, b) {
      final createdOrder = a.createdAt.compareTo(b.createdAt);
      return createdOrder == 0 ? a.id.compareTo(b.id) : createdOrder;
    });
    return comments.toList(growable: false);
  }

  void _invalidateRequests() {
    _generation++;
    _currentPostId = null;
    _failedCommentsPage = null;
    if (isClosed) return;
    emit(state.copyWith(
      clearPost: true,
      comments: const [],
      page: 0,
      totalCount: 0,
      totalPages: 0,
      isPostLoading: false,
      isCommentsLoading: false,
      isLoadingMoreComments: false,
      isLikeProcessing: false,
      isCommentSubmitting: false,
      clearDeletingCommentId: true,
      clearPostFailure: true,
      clearCommentsFailure: true,
      clearOperationFailure: true,
    ));
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
