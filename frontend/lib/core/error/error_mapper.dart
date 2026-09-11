import 'package:dio/dio.dart';

import 'app_failure.dart';

abstract final class ErrorMapper {
  static AppFailure from(Object error) {
    if (error is AppFailure) return error;
    if (error is DioException) return _fromDio(error);
    return const UnknownFailure('Ocurrió un error inesperado.');
  }

  static AppFailure _fromDio(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const TimeoutFailure('La solicitud tardó demasiado.');
    }
    if (error.type == DioExceptionType.connectionError) {
      return const NetworkFailure('No se pudo conectar con el servidor.');
    }

    final status = error.response?.statusCode;
    final message = _message(error.response?.data);
    return switch (status) {
      400 || 422 => ValidationFailure(message),
      401 => UnauthorizedFailure(message),
      403 => ForbiddenFailure(message),
      404 => NotFoundFailure(message),
      409 => ConflictFailure(message),
      429 => RateLimitFailure(message),
      500 => ServerFailure(message),
      503 => ServiceUnavailableFailure(message),
      _ => UnknownFailure(message),
    };
  }

  static String _message(Object? data) {
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return 'No se pudo completar la solicitud.';
  }
}