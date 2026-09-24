import 'package:equatable/equatable.dart';

import '../../domain/entities/community_post.dart';

class CommunityFeedState extends Equatable {
  const CommunityFeedState({
    this.items = const [],
    this.page = 0,
    this.totalPages = 0,
    this.totalCount = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.deletingPostId,
    this.failure,
    this.loadingMoreFailure,
    this.operationFailure,
  });

  final List<CommunityPost> items;
  final int page;
  final int totalPages;
  final int totalCount;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isSubmitting;
  final String? deletingPostId;
  final String? failure;
  final String? loadingMoreFailure;
  final String? operationFailure;

  bool get hasMore => page < totalPages;
  bool get isEmpty => !isInitialLoading && items.isEmpty && failure == null;

  CommunityFeedState copyWith({
    List<CommunityPost>? items,
    int? page,
    int? totalPages,
    int? totalCount,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isSubmitting,
    String? deletingPostId,
    bool clearDeletingPostId = false,
    String? failure,
    bool clearFailure = false,
    String? loadingMoreFailure,
    bool clearLoadingMoreFailure = false,
    String? operationFailure,
    bool clearOperationFailure = false,
  }) {
    return CommunityFeedState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      deletingPostId: clearDeletingPostId ? null : deletingPostId ?? this.deletingPostId,
      failure: clearFailure ? null : failure ?? this.failure,
      loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
      operationFailure: clearOperationFailure ? null : operationFailure ?? this.operationFailure,
    );
  }

  @override
  List<Object?> get props => [
        items,
        page,
        totalPages,
        totalCount,
        isInitialLoading,
        isRefreshing,
        isLoadingMore,
        isSubmitting,
        deletingPostId,
        failure,
        loadingMoreFailure,
        operationFailure,
      ];
}
