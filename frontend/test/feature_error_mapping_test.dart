import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/error_mapper.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/profile/data/models/profile_models.dart';

void main() {
  test('maps backend conflict ProblemDetails to ConflictFailure', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/motorcycles'),
      response: Response(requestOptions: RequestOptions(path: '/api/motorcycles'), statusCode: 409, data: {'detail': 'El VIN ya está registrado.'}),
    );
    final failure = ErrorMapper.from(error);
    expect(failure, isA<ConflictFailure>());
    expect(failure.message, 'El VIN ya está registrado.');
  });

  test('invalid profile date becomes a mapped serialization-safe failure', () {
    expect(
      () => ProfileModel.fromJson({'id': '1', 'userName': 'rider', 'email': 'rider@example.com', 'emailConfirmed': false, 'lastLoginAt': 'invalid'}),
      throwsA(isA<FormatException>()),
    );
  });
}
