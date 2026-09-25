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

  test('maps REST failures through ErrorMapper', () async {
    final dio = Dio()
      ..httpClientAdapter = _ErrorAdapter();
    final repository = NewsRepositoryImpl(NewsRestDataSource(dio));

    expect(() => repository.getNewsFeed(page: 1, pageSize: 20), throwsA(isA<ServiceUnavailableFailure>()));
  });
}

class _NewsAdapter implements HttpClientAdapter {
  final feedQueries = <Map<String, dynamic>>[];
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
    return ResponseBody(const Stream<Uint8List>.empty(), 404);
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody(const Stream<Uint8List>.empty(), 503);

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Object data) => ResponseBody(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(jsonEncode(data)))),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );