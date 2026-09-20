import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/network/api_client.dart';
import 'package:motohub/core/network/token_storage.dart';

void main() {
  test('rebuilds multipart body after successful JWT refresh', () async {
    final storage = _TokenStorage();
    final events = SessionEvents();
    final adapter = _MultipartRetryAdapter();
    final client = ApiClient(storage, events)..dio.httpClientAdapter = adapter;
    addTearDown(events.dispose);
    final bytes = Uint8List.fromList([7, 8, 9]);

    final response = await client.dio.post<void>(
      '/api/products/product-1/images',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg')}),
      options: Options(extra: {
        'rebuildMultipartData': () => FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: 'photo.jpg')}),
      }),
    );

    expect(response.statusCode, 200);
    expect(adapter.calls, 2);
    expect(adapter.retriedBytes, bytes);
    expect(storage.access, 'new-access');
  });
}

class _TokenStorage extends TokenStorage {
  String? access = 'old-access';
  String? refresh = 'refresh-token';

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<void> save(String accessToken, String refreshToken) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

class _MultipartRetryAdapter implements HttpClientAdapter {
  int calls = 0;
  Uint8List? retriedBytes;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/auth/refresh') {
      return _response({'accessToken': 'new-access', 'refreshToken': 'new-refresh'}, 200);
    }
    calls++;
    if (calls == 1) return _response({'detail': 'expired'}, 401);
    if (requestStream != null) {
      final requestBytes = await requestStream.fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
      final requestBody = String.fromCharCodes(requestBytes);
      final content = requestBody.contains('\r\n\r\n') ? requestBody.split('\r\n\r\n').last.split('\r\n').first : '';
      retriedBytes = Uint8List.fromList(content.codeUnits);
    }
    return _response(null, 200);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _response(Object? data, int status) => ResponseBody(Stream.value(Uint8List.fromList(utf8.encode(data == null ? '' : jsonEncode(data)))), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
}