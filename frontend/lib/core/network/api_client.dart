import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../error/app_failure.dart';
import '../auth/session_events.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this.tokenStorage, [this.sessionEvents])
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
            headers: const {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(_AuthInterceptor(dio, tokenStorage, sessionEvents));
  }

  final Dio dio;
  final TokenStorage tokenStorage;
  final SessionEvents? sessionEvents;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio, this._tokenStorage, this._sessionEvents);

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final SessionEvents? _sessionEvents;
  Future<String?>? _refreshFuture;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _tokenStorage.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException error, ErrorInterceptorHandler handler) async {
    final request = error.requestOptions;
    if (error.response?.statusCode != 401 ||
        request.extra['retried'] == true ||
        request.extra['skipAuth'] == true) {
      handler.next(error);
      return;
    }

    try {
      final accessToken = await _refreshAccessToken();
      if (accessToken == null) {
        await _invalidateSession();
        handler.next(error);
        return;
      }
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer $accessToken';
      final rebuildMultipartData = request.extra['rebuildMultipartData'];
      if (rebuildMultipartData is Function) {
        request.data = rebuildMultipartData();
        request.headers.remove(Headers.contentLengthHeader);
        request.headers.remove(Headers.contentTypeHeader);
      }
      handler.resolve(await _dio.fetch(request));
    } catch (_) {
      await _invalidateSession();
      handler.next(error);
    }
  }

  Future<String?> _refreshAccessToken() {
    final existing = _refreshFuture;
    if (existing != null) return existing;

    final refresh = _performRefresh();
    _refreshFuture = refresh;
    refresh.then<void>(
      (_) => _refreshFuture = null,
      onError: (_, __) => _refreshFuture = null,
    );
    return refresh;
  }

  Future<void> _invalidateSession() async {
    await _tokenStorage.clear();
    _sessionEvents?.invalidate();
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    final data = response.data;
    if (data == null || data['accessToken'] is! String || data['refreshToken'] is! String) {
      throw const SerializationFailure('La respuesta de sesión no es válida.');
    }
    final accessToken = data['accessToken'] as String;
    await _tokenStorage.save(accessToken, data['refreshToken'] as String);
    return accessToken;
  }
}
