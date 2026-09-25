import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/news/domain/entities/news_article.dart';
import 'package:motohub/features/news/domain/entities/news_category.dart';
import 'package:motohub/features/news/domain/entities/news_detail.dart';
import 'package:motohub/features/news/domain/entities/paged_news.dart';
import 'package:motohub/features/news/domain/repositories/news_repository.dart';
import 'package:motohub/features/news/domain/usecases/get_news_categories.dart';
import 'package:motohub/features/news/domain/usecases/get_news_feed.dart';
import 'package:motohub/features/news/presentation/cubit/news_feed_cubit.dart';

void main() {
  test('loads categories and the first page, then deduplicates load-more items', () async {
    final repository = _FakeNewsRepository(
      pages: {
        null: {
          1: _page(['one', 'two'], page: 1, totalPages: 2, totalCount: 3),
          2: _page(['two', 'three'], page: 2, totalPages: 2, totalCount: 3),
        },
      },
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    await cubit.loadMore();

    expect(cubit.state.categories.single.slug, 'rutas');
    expect(cubit.state.items.map((item) => item.id), ['one', 'two', 'three']);
    expect(repository.requestedPages, [1, 2]);
  });

  test('retries the exact failed load-more page and keeps previous items visible', () async {
    final repository = _FakeNewsRepository(
      pages: {
        null: {
          1: _page(['one'], page: 1, totalPages: 3, totalCount: 3),
          2: _page(['two'], page: 2, totalPages: 3, totalCount: 3),
          3: _page(['three'], page: 3, totalPages: 3, totalCount: 3),
        },
      },
      failingPages: {3},
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    await cubit.loadMore();
    await cubit.loadMore();

    expect(cubit.state.items.map((item) => item.id), ['one', 'two']);
    expect(cubit.state.failedPage, 3);
    repository.failingPages.clear();
    await cubit.retryLoadMore();

    expect(repository.requestedPages, [1, 2, 3, 3]);
    expect(cubit.state.items.map((item) => item.id), ['one', 'two', 'three']);
    expect(cubit.state.failedPage, isNull);
  });

  test('selecting a category resets to page one and All clears the category', () async {
    final repository = _FakeNewsRepository(
      pages: {
        null: {1: _page(['all'], page: 1, totalPages: 1, totalCount: 1)},
        'cat-1': {1: _page(['filtered'], page: 1, totalPages: 1, totalCount: 1)},
      },
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    await cubit.selectCategory('cat-1');
    expect(cubit.state.selectedCategoryId, 'cat-1');
    expect(cubit.state.items.single.id, 'filtered');
    await cubit.selectCategory(null);

    expect(cubit.state.selectedCategoryId, isNull);
    expect(cubit.state.items.single.id, 'all');
    expect(repository.requestedCategories, [null, 'cat-1', null]);
  });

  test('stale category response cannot replace the newer category', () async {
    final oldCategory = Completer<PagedNews>();
    final newCategory = Completer<PagedNews>();
    final repository = _FakeNewsRepository(
      pages: {null: {1: _page(['all'], page: 1, totalPages: 1, totalCount: 1)}},
      pendingByCategory: {'cat-a': oldCategory.future, 'cat-b': newCategory.future},
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    final first = cubit.selectCategory('cat-a');
    final second = cubit.selectCategory('cat-b');
    oldCategory.complete(_page(['old'], page: 1, totalPages: 1, totalCount: 1));
    newCategory.complete(_page(['new'], page: 1, totalPages: 1, totalCount: 1));
    await Future.wait([first, second]);

    expect(cubit.state.selectedCategoryId, 'cat-b');
    expect(cubit.state.items.single.id, 'new');
  });

  test('session invalidation discards a pending response', () async {
    final pending = Completer<PagedNews>();
    final sessionEvents = SessionEvents();
    final repository = _FakeNewsRepository(pendingByCategory: {null: pending.future});
    final cubit = NewsFeedCubit(GetNewsFeed(repository), GetNewsCategories(repository), sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    final load = cubit.loadInitial();
    sessionEvents.invalidate();
    pending.complete(_page(['stale'], page: 1, totalPages: 1, totalCount: 1));
    await load;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.isInitialLoading, isFalse);
  });

  test('category failure does not destroy a valid feed', () async {
    final repository = _FakeNewsRepository(
      pages: {null: {1: _page(['one'], page: 1, totalPages: 1, totalCount: 1)}},
      categoriesFailure: true,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();

    expect(cubit.state.items.single.id, 'one');
    expect(cubit.state.categoriesFailure, isNotNull);
  });

  test('concurrent load-more calls request one page only', () async {
    final pending = Completer<PagedNews>();
    final repository = _FakeNewsRepository(
      pages: {null: {1: _page(['one'], page: 1, totalPages: 2, totalCount: 2)}},
      pendingByPage: {2: pending.future},
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.loadInitial();
    final first = cubit.loadMore();
    final second = cubit.loadMore();
    pending.complete(_page(['two'], page: 2, totalPages: 2, totalCount: 2));
    await Future.wait([first, second]);

    expect(repository.requestedPages, [1, 2]);
    expect(cubit.state.items.map((item) => item.id), ['one', 'two']);
  });
}

NewsFeedCubit _createCubit(_FakeNewsRepository repository) => NewsFeedCubit(GetNewsFeed(repository), GetNewsCategories(repository));

PagedNews _page(List<String> ids, {required int page, required int totalPages, required int totalCount}) => PagedNews(
      items: ids.map(_article).toList(growable: false),
      page: page,
      pageSize: 20,
      totalCount: totalCount,
      totalPages: totalPages,
    );

NewsArticle _article(String id) => NewsArticle(
      id: id,
      slug: id,
      title: id,
      summary: null,
      featuredImageUrl: null,
      categories: const [],
      publishedAt: DateTime.utc(2026, 9, 24),
    );

class _FakeNewsRepository implements NewsRepository {
  _FakeNewsRepository({this.pages = const {}, this.failingPages = const {}, this.pendingByCategory = const {}, this.pendingByPage = const {}, this.categoriesFailure = false});

  final Map<String?, Map<int, PagedNews>> pages;
  final Set<int> failingPages;
  final Map<String?, Future<PagedNews>> pendingByCategory;
  final Map<int, Future<PagedNews>> pendingByPage;
  final bool categoriesFailure;
  final requestedPages = <int>[];
  final requestedCategories = <String?>[];

  @override
  Future<List<NewsCategory>> getNewsCategories() => categoriesFailure
      ? Future.error(const NetworkFailure('No se pudieron cargar las categorías.'))
      : Future.value(const [NewsCategory(id: 'cat-1', name: 'Rutas', slug: 'rutas')]);

  @override
  Future<NewsDetail> getNewsDetail(String newsId) => Future.error(UnsupportedError('Not used in feed tests'));

  @override
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId}) {
    requestedPages.add(page);
    requestedCategories.add(categoryId);
    final pending = pendingByCategory[categoryId] ?? pendingByPage[page];
    if (pending != null) return pending;
    if (failingPages.contains(page)) return Future.error(const NetworkFailure('No se pudo cargar la página.'));
    return Future.value(pages[categoryId]?[page] ?? _page([], page: page, totalPages: page, totalCount: 0));
  }
}