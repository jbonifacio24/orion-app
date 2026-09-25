import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_events.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/usecases/get_news_categories.dart';
import '../../domain/usecases/get_news_feed.dart';
import 'news_feed_state.dart';

class NewsFeedCubit extends Cubit<NewsFeedState> {
  NewsFeedCubit(this._getNewsFeed, this._getNewsCategories, [SessionEvents? sessionEvents]) : super(const NewsFeedState()) {
    _sessionSubscription = sessionEvents?.onInvalidated.listen((_) => _invalidateRequests());
  }

  static const pageSize = 20;

  final GetNewsFeed _getNewsFeed;
  final GetNewsCategories _getNewsCategories;
  StreamSubscription<void>? _sessionSubscription;
  int _generation = 0;
  int _feedOperationToken = 0;
  int _categoriesOperationToken = 0;

  Future<void> loadInitial() async {
    if (state.isInitialLoading || state.isRefreshing) return;
    final generation = ++_generation;
    emit(state.copyWith(
      isInitialLoading: state.items.isEmpty,
      isRefreshing: false,
      isLoadingMore: false,
      isCategoriesLoading: true,
      clearFailure: true,
      clearLoadingMoreFailure: true,
      clearCategoriesFailure: true,
      clearFailedPage: true,
    ));
    await Future.wait([
      _loadCategories(generation),
      _loadPage(1, reset: true, generation: generation),
    ]);
  }

  Future<void> refresh() async {
    if (state.isRefreshing || state.isInitialLoading || state.isLoadingMore) return;
    final generation = ++_generation;
    emit(state.copyWith(
      isRefreshing: true,
      isInitialLoading: false,
      clearFailure: true,
      clearLoadingMoreFailure: true,
      clearFailedPage: true,
    ));
    await _loadPage(1, reset: true, refreshing: true, generation: generation);
  }

  Future<void> retry() async {
    if (state.isInitialLoading || state.isRefreshing || state.isLoadingMore) return;
    final generation = ++_generation;
    emit(state.copyWith(
      isInitialLoading: state.items.isEmpty,
      isRefreshing: state.items.isNotEmpty,
      clearFailure: true,
      clearLoadingMoreFailure: true,
      clearFailedPage: true,
    ));
    await _loadPage(1, reset: true, refreshing: state.items.isNotEmpty, generation: generation);
  }

  Future<void> loadMore() async {
    if (state.page == 0 || !state.hasMore || state.isInitialLoading || state.isRefreshing || state.isLoadingMore) return;
    await _loadPage(state.page + 1, reset: false, generation: _generation);
  }

  Future<void> retryLoadMore() async {
    final failedPage = state.failedPage;
    if (failedPage == null || state.isInitialLoading || state.isRefreshing || state.isLoadingMore) return;
    await _loadPage(failedPage, reset: false, generation: _generation);
  }

  Future<void> selectCategory(String? categoryId) async {
    if (state.selectedCategoryId == categoryId) return;
    final generation = ++_generation;
    emit(state.copyWith(
      items: const [],
      selectedCategoryId: categoryId,
      clearSelectedCategoryId: categoryId == null,
      page: 0,
      totalCount: 0,
      totalPages: 0,
      isInitialLoading: true,
      isRefreshing: false,
      isLoadingMore: false,
      clearFailure: true,
      clearLoadingMoreFailure: true,
      clearFailedPage: true,
    ));
    await _loadPage(1, reset: true, generation: generation);
  }

  Future<void> retryCategories() {
    if (state.isCategoriesLoading) return Future.value();
    emit(state.copyWith(isCategoriesLoading: true, clearCategoriesFailure: true));
    return _loadCategories(_generation);
  }

  Future<void> _loadPage(int page, {required bool reset, required int generation, bool refreshing = false}) async {
    final operationToken = ++_feedOperationToken;
    if (!reset) {
      emit(state.copyWith(isLoadingMore: true, clearLoadingMoreFailure: true));
    }
    try {
      final result = await _getNewsFeed(page: page, pageSize: pageSize, categoryId: state.selectedCategoryId);
      if (isClosed || generation != _generation || operationToken != _feedOperationToken) return;
      final items = reset ? _deduplicate(result.items) : _merge(state.items, result.items);
      emit(state.copyWith(
        items: items,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
        totalPages: result.totalPages,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        clearFailure: true,
        clearLoadingMoreFailure: true,
        clearFailedPage: true,
      ));
    } catch (error) {
      if (isClosed || generation != _generation || operationToken != _feedOperationToken) return;
      final message = ErrorMapper.from(error).message;
      if (reset) {
        emit(state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          failure: message,
        ));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreFailure: message, failedPage: page));
      }
    }
  }

  Future<void> _loadCategories(int generation) async {
    final operationToken = ++_categoriesOperationToken;
    try {
      final categories = await _getNewsCategories();
      if (isClosed || generation != _generation || operationToken != _categoriesOperationToken) return;
      emit(state.copyWith(categories: categories, isCategoriesLoading: false, clearCategoriesFailure: true));
    } catch (error) {
      if (isClosed || generation != _generation || operationToken != _categoriesOperationToken) return;
      emit(state.copyWith(isCategoriesLoading: false, categoriesFailure: ErrorMapper.from(error).message));
    }
  }

  List<NewsArticle> _deduplicate(List<NewsArticle> items) {
    final byId = <String, NewsArticle>{};
    for (final item in items) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  List<NewsArticle> _merge(List<NewsArticle> current, List<NewsArticle> incoming) {
    final byId = <String, NewsArticle>{for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  void _invalidateRequests() {
    _generation++;
    _feedOperationToken++;
    _categoriesOperationToken++;
    if (!isClosed) {
      emit(state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        isCategoriesLoading: false,
      ));
    }
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}