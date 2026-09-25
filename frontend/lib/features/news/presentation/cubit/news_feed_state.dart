import 'package:equatable/equatable.dart';

import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';

class NewsFeedState extends Equatable {
  const NewsFeedState({
    this.items = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.page = 0,
    this.pageSize = 20,
    this.totalCount = 0,
    this.totalPages = 0,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isCategoriesLoading = false,
    this.failure,
    this.loadingMoreFailure,
    this.categoriesFailure,
    this.failedPage,
  });

  final List<NewsArticle> items;
  final List<NewsCategory> categories;
  final String? selectedCategoryId;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isCategoriesLoading;
  final String? failure;
  final String? loadingMoreFailure;
  final String? categoriesFailure;
  final int? failedPage;

  bool get hasMore => page < totalPages;
  bool get isEmpty => !isInitialLoading && items.isEmpty && failure == null;

  NewsFeedState copyWith({
    List<NewsArticle>? items,
    List<NewsCategory>? categories,
    String? selectedCategoryId,
    bool clearSelectedCategoryId = false,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isCategoriesLoading,
    String? failure,
    bool clearFailure = false,
    String? loadingMoreFailure,
    bool clearLoadingMoreFailure = false,
    String? categoriesFailure,
    bool clearCategoriesFailure = false,
    int? failedPage,
    bool clearFailedPage = false,
  }) => NewsFeedState(
        items: items ?? this.items,
        categories: categories ?? this.categories,
        selectedCategoryId: clearSelectedCategoryId ? null : selectedCategoryId ?? this.selectedCategoryId,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        totalCount: totalCount ?? this.totalCount,
        totalPages: totalPages ?? this.totalPages,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isCategoriesLoading: isCategoriesLoading ?? this.isCategoriesLoading,
        failure: clearFailure ? null : failure ?? this.failure,
        loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
        categoriesFailure: clearCategoriesFailure ? null : categoriesFailure ?? this.categoriesFailure,
        failedPage: clearFailedPage ? null : failedPage ?? this.failedPage,
      );

  @override
  List<Object?> get props => [
        items,
        categories,
        selectedCategoryId,
        page,
        pageSize,
        totalCount,
        totalPages,
        isInitialLoading,
        isRefreshing,
        isLoadingMore,
        isCategoriesLoading,
        failure,
        loadingMoreFailure,
        categoriesFailure,
        failedPage,
      ];
}