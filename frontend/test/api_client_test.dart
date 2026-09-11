import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/network/api_client.dart';
import 'package:motohub/core/network/token_storage.dart';

void main() {
  test('refreshes a 401 request and retries successfully', () async {
    final storage = _FakeTokenStorage('old-access', 'refresh-token');
    final events = SessionEvents();
    final adapter = _RefreshAdapter();
    final client = _client(storage, events, adapter);
    addTearDown(events.dispose);

    final response = await client.dio.get<Map<String, dynamic>>('/resource');

    expect(response.data, {'ok': true});
    expect(adapter.refreshCalls, 1);
    expect(adapter.resourceCalls, 2);
    expect(storage.accessTokenValue, 'new-access');
    expect(storage.refreshTokenValue, 'new-refresh');
  });

  test('failed refresh clears storage and invalidates the session', () async {
    final storage = _FakeTokenStorage('old-access', 'refresh-token');
    final events = SessionEvents();
    final adapter = _RefreshAdapter(refreshFails: true);
    final client = _client(storage, events, adapter);
    var invalidations = 0;
    final subscription = events.onInvalidated.listen((_) => invalidations++);
    addTearDown(() async {
      await subscription.cancel();
      await events.dispose();
    });

    await expectLater(client.dio.get<void>('/resource'), throwsA(isA<DioException>()));

    expect(adapter.refreshCalls, 1);
    expect(storage.clearCalls, greaterThanOrEqualTo(1));
    expect(storage.accessTokenValue, isNull);
    expect(storage.refreshTokenValue, isNull);
    expect(invalidations, greaterThanOrEqualTo(1));
  });

  test('does not refresh a request more than once', () async {
    final storage = _FakeTokenStorage('old-access', 'refresh-token');
    final events = SessionEvents();
    final adapter = _RefreshAdapter(alwaysUnauthorized: true);
    final client = _client(storage, events, adapter);
    addTearDown(events.dispose);

    await expectLater(client.dio.get<void>('/resource'), throwsA(isA<DioException>()));

    expect(adapter.refreshCalls, 1);
    expect(adapter.resourceCalls, 2);
  });

  test('three concurrent 401 requests share one successful refresh', () async {
    final storage = _FakeTokenStorage('old-access', 'refresh-token');
    final events = SessionEvents();
    final adapter = _RefreshAdapter(refreshDelay: const Duration(milliseconds: 10));
    final client = _client(storage, events, adapter);
    addTearDown(events.dispose);

    final responses = await Future.wait([
      client.dio.get<Map<String, dynamic>>('/resource/a'),
      client.dio.get<Map<String, dynamic>>('/resource/b'),
      client.dio.get<Map<String, dynamic>>('/resource/c'),
    ]);

    expect(responses.map((response) => response.data), everyElement({'ok': true}));
    expect(adapter.refreshCalls, 1);
    expect(adapter.resourceCalls, 6);
    expect(storage.saveCalls, 1);
  });

  test('three concurrent 401 requests share one failed refresh', () async {
    final storage = _FakeTokenStorage('old-access', 'refresh-token');
    final events = SessionEvents();
    final adapter = _RefreshAdapter(
      refreshFails: true,
      refreshDelay: const Duration(milliseconds: 10),
    );
    final client = _client(storage, events, adapter);
    var invalidations = 0;
    final subscription = events.onInvalidated.listen((_) => invalidations++);
    addTearDown(() async {
      await subscription.cancel();
      await events.dispose();
    });

    final results = await Future.wait([
      client.dio.get<void>('/resource/a').then<void>((_) {}, onError: (_) {}),
      client.dio.get<void>('/resource/b').then<void>((_) {}, onError: (_) {}),
      client.dio.get<void>('/resource/c').then<void>((_) {}, onError: (_) {}),
    ]);

    expect(results, hasLength(3));
    expect(adapter.refreshCalls, 1);
    expect(storage.accessTokenValue, isNull);
    expect(storage.refreshTokenValue, isNull);
    expect(invalidations, greaterThanOrEqualTo(1));
  });
}

ApiClient _client(
  _FakeTokenStorage storage,
  SessionEvents events,
  _RefreshAdapter adapter,
) {
  final client = ApiClient(storage, events);
  client.dio.httpClientAdapter = adapter;
  return client;
}

class _FakeTokenStorage extends TokenStorage {
  _FakeTokenStorage(this.accessTokenValue, this.refreshTokenValue);

  String? accessTokenValue;
  String? refreshTokenValue;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<String?> get accessToken async => accessTokenValue;

  @override
  Future<String?> get refreshToken async => refreshTokenValue;

  @override
  Future<void> save(String accessToken, String refreshToken) async {
    saveCalls++;
    accessTokenValue = accessToken;
    refreshTokenValue = refreshToken;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    accessTokenValue = null;
    refreshTokenValue = null;
  }
}

class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({
    this.refreshFails = false,
    this.alwaysUnauthorized = false,
    this.refreshDelay = Duration.zero,
  });

  final bool refreshFails;
  final bool alwaysUnauthorized;
  final Duration refreshDelay;
  int refreshCalls = 0;
  int resourceCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      if (refreshDelay > Duration.zero) await Future<void>.delayed(refreshDelay);
      if (refreshFails) return _jsonResponse({'error': 'invalid'}, 401);
      return _jsonResponse({'accessToken': 'new-access', 'refreshToken': 'new-refresh'}, 200);
    }

    resourceCalls++;
    final retried = options.extra['retried'] == true;
    if (!retried || alwaysUnauthorized) return _jsonResponse({'error': 'expired'}, 401);
    return _jsonResponse({'ok': true}, 200);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> data, int statusCode) {
  return ResponseBody(
    Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(jsonEncode(data)))),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}