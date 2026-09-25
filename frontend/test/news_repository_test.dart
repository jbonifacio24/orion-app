import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/news/data/datasources/news_rest_data_source.dart';
import 'package:motohub/features/news/data/repositories/news_repository_impl.dart';

void main() {
  test('requests feed pagination and omits categoryId for All', () async {
    final adapter = _NewsAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    await repository.getNewsFeed(page: 2, pageSize: 20);
    await repository.getNewsFeed(page: 1, pageSize: 20, categoryId: 'cat-1');

    expect(adapter.feedQueries, [
      {'page': 2, 'pageSize': 20},
      {'page': 1, 'pageSize': 20, 'categoryId': 'cat-1'},
    ]);
  });

  test('requests and maps the unpaged categories endpoint', () async {
    final adapter = _NewsAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    final categories = await repository.getNewsCategories();

    expect(categories.single.slug, 'rutas');
    expect(adapter.categoriesCalls, 1);
  });

  test('requests and maps a detail by encoded ID', () async {
    final adapter = _NewsAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    final detail = await repository.getNewsDetail('news/one');

    expect(detail.content, 'Full news content');
    expect(adapter.detailPaths, ['/api/news/news%2Fone']);
  });

  test('maps REST failures through ErrorMapper', () async {
    final dio = Dio()
      ..httpClientAdapter = const _ErrorAdapter(503);
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    expect(() => repository.getNewsFeed(page: 1, pageSize: 20), throwsA(isA<ServiceUnavailableFailure>()));
  });

  test('maps a detail 404 through ErrorMapper', () async {
    final dio = Dio()..httpClientAdapter = const _ErrorAdapter(404);
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    expect(() => repository.getNewsDetail('news-1'), throwsA(isA<NotFoundFailure>()));
  });
}

class _NewsAdapter implements HttpClientAdapter {
  final feedQueries = <Map<String, dynamic>>[];
  final detailPaths = <String>[];
  int categoriesCalls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/api/news') {
      feedQueries.add(Map<String, dynamic>.from(options.queryParameters));
      return _jsonResponse({
        'items': [],
        'page': options.queryParameters['page'],
        'pageSize': options.queryParameters['pageSize'],
        'totalCount': 0,
        'totalPages': 0,
      });
    }
    if (options.path == '/api/news/categories') {
      categoriesCalls++;
      return _jsonResponse([
        {'id': 'cat-1', 'name': 'Rutas', 'slug': 'rutas'},
      ]);
    }
    if (options.path.startsWith('/api/news/')) {
      detailPaths.add(options.path);
      return _jsonResponse({
        'id': 'news-1',
        'slug': 'ruta-andina',
        'title': 'Ruta andina',
        'summary': 'Summary',
        'content': 'Full news content',
        'featuredImageUrl': null,
        'categories': [],
        'publishedAt': '2026-09-24T12:00:00Z',
      });
    }
    return ResponseBody(const Stream<Uint8List>.empty(), 404);
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  const _ErrorAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody(const Stream<Uint8List>.empty(), status);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object data) => ResponseBody(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(jsonEncode(data)))),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );