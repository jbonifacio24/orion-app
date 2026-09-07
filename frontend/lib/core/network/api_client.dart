import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient(this.tokenStorage)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: const {'Content-Type': 'application/json'},
          ),
          ) {
      dio.interceptors.add(_AuthInterceptor(dio, tokenStorage));
    }

  final Dio dio;
    final TokenStorage tokenStorage;
}

  class _AuthInterceptor extends Interceptor {
    _AuthInterceptor(this._dio, this._tokenStorage);

    final Dio _dio;
    final TokenStorage _tokenStorage;
    bool _refreshing = false;

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
      if (error.response?.statusCode != 401 || request.extra['retried'] == true || _refreshing) {
        handler.next(error);
        return;
      }

      final refreshToken = await _tokenStorage.refreshToken;
      if (refreshToken == null) {
        handler.next(error);
        return;
      }

      _refreshing = true;
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
          options: Options(extra: {'skipAuth': true}),
        );
        final data = response.data!;
        await _tokenStorage.save(data['accessToken'] as String, data['refreshToken'] as String);
        request.extra['retried'] = true;
        request.headers['Authorization'] = 'Bearer ${data['accessToken']}';
        handler.resolve(await _dio.fetch(request));
      } on DioException {
        await _tokenStorage.clear();
        handler.next(error);
      } finally {
        _refreshing = false;
      }
    }
  }
