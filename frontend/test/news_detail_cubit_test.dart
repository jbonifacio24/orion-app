import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/news/domain/entities/news_category.dart';
import 'package:motohub/features/news/domain/entities/news_detail.dart';
import 'package:motohub/features/news/domain/entities/paged_news.dart';
import 'package:motohub/features/news/domain/repositories/news_repository.dart';
import 'package:motohub/features/news/domain/usecases/get_news_detail.dart';
import 'package:motohub/features/news/presentation/cubit/news_detail_cubit.dart';

void main() {
  test('loads detail successfully and retries the same ID', () async {
    final repository = _DetailRepository(responses: {
      'news-1': [
        Future<NewsDetail>.error(const NetworkFailure('temporary')),
        Future.value(_detail('news-1')),
      ],
    });
    final cubit = NewsDetailCubit(GetNewsDetail(repository));
    addTearDown(cubit.close);

    await cubit.load('news-1');
    expect(cubit.state.failure, isNotNull);
    await cubit.retry();

    expect(repository.requestedIds, ['news-1', 'news-1']);
    expect(cubit.state.news?.id, 'news-1');
  });

  test('exposes a generic not found state for a 404', () async {
    final repository = _DetailRepository(responses: {
      'missing': [Future<NewsDetail>.error(const NotFoundFailure('not found'))],
    });
    final cubit = NewsDetailCubit(GetNewsDetail(repository));
    addTearDown(cubit.close);

    await cubit.load('missing');

    expect(cubit.state.isNotFound, isTrue);
    expect(cubit.state.news, isNull);
  });

  test('a stale ID response cannot clear or replace the newer operation', () async {
    final first = Completer<NewsDetail>();
    final second = Completer<NewsDetail>();
    final repository = _DetailRepository(pending: {'news-a': first.future, 'news-b': second.future});
    final cubit = NewsDetailCubit(GetNewsDetail(repository));
    addTearDown(cubit.close);

    final loadA = cubit.load('news-a');
    final loadB = cubit.load('news-b');
    first.complete(_detail('news-a'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.news, isNull);
    second.complete(_detail('news-b'));
    await Future.wait([loadA, loadB]);

    expect(cubit.state.news?.id, 'news-b');
  });

  test('session invalidation discards a pending detail response', () async {
    final pending = Completer<NewsDetail>();
    final sessionEvents = SessionEvents();
    final repository = _DetailRepository(pending: {'news-1': pending.future});
    final cubit = NewsDetailCubit(GetNewsDetail(repository), sessionEvents);
    addTearDown(() async {
      await cubit.close();
      await sessionEvents.dispose();
    });

    final load = cubit.load('news-1');
    sessionEvents.invalidate();
    pending.complete(_detail('news-1'));
    await load;

    expect(cubit.state.news, isNull);
    expect(cubit.state.isLoading, isFalse);
  });
}

NewsDetail _detail(String id) => NewsDetail(
      id: id,
      slug: id,
      title: id,
      summary: 'Summary',
      content: 'Content for $id',
      featuredImageUrl: null,
      categories: const [NewsCategory(id: 'cat-1', name: 'Rutas', slug: 'rutas')],
      publishedAt: DateTime.utc(2026, 9, 24),
    );

class _DetailRepository implements NewsRepository {
  _DetailRepository({this.responses = const {}, this.pending = const {}});

  final Map<String, List<Future<NewsDetail>>> responses;
  final Map<String, Future<NewsDetail>> pending;
  final requestedIds = <String>[];

  @override
  Future<List<NewsCategory>> getNewsCategories() => Future.value(const []);

  @override
  Future<NewsDetail> getNewsDetail(String newsId) {
    requestedIds.add(newsId);
    final pendingResponse = pending[newsId];
    if (pendingResponse != null) return pendingResponse;
    final queuedResponses = responses[newsId];
    if (queuedResponses == null || queuedResponses.isEmpty) return Future.value(_detail(newsId));
    return queuedResponses.removeAt(0);
  }

  @override
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId}) =>
      Future.error(UnsupportedError('Not used in detail tests'));
}