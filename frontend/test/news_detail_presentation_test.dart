import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/news/domain/entities/news_category.dart';
import 'package:motohub/features/news/domain/entities/news_detail.dart';
import 'package:motohub/features/news/domain/entities/paged_news.dart';
import 'package:motohub/features/news/domain/repositories/news_repository.dart';
import 'package:motohub/features/news/domain/usecases/get_news_detail.dart';
import 'package:motohub/features/news/presentation/cubit/news_detail_cubit.dart';
import 'package:motohub/features/news/presentation/pages/news_detail_page.dart';

void main() {
  testWidgets('renders loading and then detail content with image fallback', (tester) async {
    final pending = Completer<NewsDetail>();
    final cubit = NewsDetailCubit(GetNewsDetail(_PageRepository(pending.future)));
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit));
    final load = cubit.load('news-1');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_detail(summary: null, categories: const [], featuredImageUrl: null));
    await load;
    await tester.pumpAndSettle();

    expect(find.text('Ruta andina'), findsOneWidget);
    expect(find.text('Plain content\nwith a line break'), findsOneWidget);
    expect(find.text('Summary'), findsNothing);
    expect(find.text('Image unavailable'), findsOneWidget);
  });

  testWidgets('renders not found error and retries the same ID', (tester) async {
    final repository = _PageRepository.queue([
      Future<NewsDetail>.error(const NotFoundFailure('not found')),
      Future.value(_detail(featuredImageUrl: null)),
    ]);
    final cubit = NewsDetailCubit(GetNewsDetail(repository));
    addTearDown(cubit.close);

    await cubit.load('news-1');
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('News could not be found.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.requestedIds, ['news-1', 'news-1']);
    expect(find.text('Plain content\nwith a line break'), findsOneWidget);
    expect(find.text('Rutas'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
  });
}

Widget _app(NewsDetailCubit cubit) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      home: BlocProvider.value(value: cubit, child: const NewsDetailPage()),
    );

NewsDetail _detail({String? summary = 'Summary', List<NewsCategory> categories = const [NewsCategory(id: 'cat-1', name: 'Rutas', slug: 'rutas')], String? featuredImageUrl = 'https://example.test/news.jpg'}) => NewsDetail(
      id: 'news-1',
      slug: 'ruta-andina',
      title: 'Ruta andina',
      summary: summary,
      content: 'Plain content\nwith a line break',
      featuredImageUrl: featuredImageUrl,
      categories: categories,
      publishedAt: DateTime.utc(2026, 9, 24),
    );

class _PageRepository implements NewsRepository {
  _PageRepository(this.detailFuture) : _responses = null;

  _PageRepository.queue(List<Future<NewsDetail>> responses)
      : detailFuture = null,
        _responses = responses;

  final Future<NewsDetail>? detailFuture;
  final List<Future<NewsDetail>>? _responses;
  final requestedIds = <String>[];

  @override
  Future<List<NewsCategory>> getNewsCategories() => Future.value(const []);

  @override
  Future<NewsDetail> getNewsDetail(String newsId) {
    requestedIds.add(newsId);
    final responses = _responses;
    if (responses != null) return responses.removeAt(0);
    return detailFuture!;
  }

  @override
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId}) =>
      Future.error(UnsupportedError('Not used in detail page tests'));
}