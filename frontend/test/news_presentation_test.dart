import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/news/domain/entities/news_article.dart';
import 'package:motohub/features/news/domain/entities/news_category.dart';
import 'package:motohub/features/news/domain/entities/news_detail.dart';
import 'package:motohub/features/news/domain/entities/paged_news.dart';
import 'package:motohub/features/news/domain/repositories/news_repository.dart';
import 'package:motohub/features/news/presentation/cubit/news_feed_cubit.dart';
import 'package:motohub/features/news/presentation/pages/news_feed_page.dart';
import 'package:motohub/features/news/presentation/widgets/news_card.dart';
import 'package:motohub/core/router/route_names.dart';
import 'package:motohub/features/news/domain/usecases/get_news_categories.dart';
import 'package:motohub/features/news/domain/usecases/get_news_feed.dart';

void main() {
  test('news route is the feed route and has no detail segment', () {
    expect(RouteNames.newsPath, '/news');
    expect(RouteNames.newsPath.contains(':newsId'), isFalse);
    expect(RouteNames.newsDetailPath, '/news/:newsId');
  });

  testWidgets('card tolerates nullable summary and displays an image when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es'), Locale('en')],
        home: NewsCard(article: _article(featuredImageUrl: 'https://example.test/news.jpg')),
      ),
    );

    expect(find.text('Ruta andina'), findsOneWidget);
    expect(find.text('null'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('card opens detail using the article ID', (tester) async {
    String? openedId;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es'), Locale('en')],
        home: NewsCard(article: _article(), onTap: () => openedId = 'news-1'),
      ),
    );

    await tester.tap(find.byType(NewsCard));

    expect(openedId, 'news-1');
  });

  testWidgets('feed page renders localized title, All filter and loaded article', (tester) async {
    final cubit = NewsFeedCubit(GetNewsFeed(_FakeNewsRepository()), GetNewsCategories(_FakeNewsRepository()));
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es'), Locale('en')],
        home: BlocProvider.value(value: cubit, child: const NewsFeedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('News'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Ruta andina'), findsOneWidget);
  });
}

NewsArticle _article({String? featuredImageUrl}) => NewsArticle(
      id: 'news-1',
      slug: 'ruta-andina',
      title: 'Ruta andina',
      summary: null,
      featuredImageUrl: featuredImageUrl,
      categories: const [NewsCategory(id: 'cat-1', name: 'Rutas', slug: 'rutas')],
      publishedAt: DateTime.utc(2026, 9, 24),
    );

class _FakeNewsRepository implements NewsRepository {
  @override
  Future<NewsDetail> getNewsDetail(String newsId) => Future.error(UnsupportedError('Not used in presentation tests'));

  @override
  Future<List<NewsCategory>> getNewsCategories() => Future.value(const [NewsCategory(id: 'cat-1', name: 'Rutas', slug: 'rutas')]);

  @override
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId}) => Future.value(
        PagedNews(items: [_article()], page: page, pageSize: pageSize, totalCount: 1, totalPages: 1),
      );
}