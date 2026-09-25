import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/news/data/models/news_models.dart';

void main() {
  test('maps a paged news summary with nullable fields and N:N categories', () {
    final page = PagedNewsModel.fromJson({
      'items': [
        {
          'id': 'news-1',
          'slug': 'ruta-andina',
          'title': 'Ruta andina',
          'summary': null,
          'featuredImageUrl': null,
          'categories': [
            {'id': 'cat-1', 'name': 'Rutas', 'slug': 'rutas'},
            {'id': 'cat-2', 'name': 'Viajes', 'slug': 'viajes'},
          ],
          'publishedAt': '2026-09-24T12:00:00Z',
        },
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });

    final article = page.items.single;
    expect(article.id, 'news-1');
    expect(article.summary, isNull);
    expect(article.featuredImageUrl, isNull);
    expect(article.categories.map((category) => category.slug), ['rutas', 'viajes']);
    expect(article.publishedAt, DateTime.utc(2026, 9, 24, 12).toLocal());
  });

  test('rejects malformed required news fields and collections', () {
    expect(
      () => NewsCategoryModel.fromJson({'id': 'cat-1', 'name': '', 'slug': 'rutas'}),
      throwsA(isA<SerializationFailure>()),
    );
    expect(
      () => NewsArticleModel.fromJson({'id': 'news-1', 'slug': 'news', 'title': 'News', 'categories': []}),
      throwsA(isA<SerializationFailure>()),
    );
    expect(
      () => PagedNewsModel.fromJson({'items': null}),
      throwsA(isA<SerializationFailure>()),
    );
  });
}