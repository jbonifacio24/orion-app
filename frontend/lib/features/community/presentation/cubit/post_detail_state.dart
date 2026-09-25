import 'package:equatable/equatable.dart';

import '../../domain/entities/community_comment.dart';
import '../../domain/entities/community_post.dart';

class PostDetailState extends Equatable {
  const PostDetailState({
    this.post,
    this.comments = const [],
    this.page = 0,
    this.pageSize = 20,
    this.totalCount = 0,
    this.totalPages = 0,
    this.isPostLoading = false,
    this.isCommentsLoading = false,
    this.isLoadingMoreComments = false,
    this.isLikeProcessing = false,
    this.isCommentSubmitting = false,
    this.deletingCommentId,
    this.postFailure,
    this.commentsFailure,
    this.operationFailure,
  });

  final CommunityPost? post;
  final List<CommunityComment> comments;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool isPostLoading;
  final bool isCommentsLoading;
  final bool isLoadingMoreComments;
  final bool isLikeProcessing;
  final bool isCommentSubmitting;
  final String? deletingCommentId;
  final String? postFailure;
  final String? commentsFailure;
  final String? operationFailure;

  bool get hasMoreComments => page < totalPages;

  PostDetailState copyWith({
    CommunityPost? post,
    bool clearPost = false,
    List<CommunityComment>? comments,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    bool? isPostLoading,
    bool? isCommentsLoading,
    bool? isLoadingMoreComments,
    bool? isLikeProcessing,
    bool? isCommentSubmitting,
    String? deletingCommentId,
    bool clearDeletingCommentId = false,
    String? postFailure,
    bool clearPostFailure = false,
    String? commentsFailure,
    bool clearCommentsFailure = false,
    String? operationFailure,
    bool clearOperationFailure = false,
  }) {
    return PostDetailState(
      post: clearPost ? null : post ?? this.post,
      comments: comments ?? this.comments,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isPostLoading: isPostLoading ?? this.isPostLoading,
      isCommentsLoading: isCommentsLoading ?? this.isCommentsLoading,
      isLoadingMoreComments: isLoadingMoreComments ?? this.isLoadingMoreComments,
      isLikeProcessing: isLikeProcessing ?? this.isLikeProcessing,
      isCommentSubmitting: isCommentSubmitting ?? this.isCommentSubmitting,
      deletingCommentId: clearDeletingCommentId ? null : deletingCommentId ?? this.deletingCommentId,
      postFailure: clearPostFailure ? null : postFailure ?? this.postFailure,
      commentsFailure: clearCommentsFailure ? null : commentsFailure ?? this.commentsFailure,
      operationFailure: clearOperationFailure ? null : operationFailure ?? this.operationFailure,
    );
  }

  @override
  List<Object?> get props => [
        post,
        comments,
        page,
        pageSize,
        totalCount,
        totalPages,
        isPostLoading,
        isCommentsLoading,
        isLoadingMoreComments,
        isLikeProcessing,
        isCommentSubmitting,
        deletingCommentId,
        postFailure,
        commentsFailure,
        operationFailure,
      ];
}
