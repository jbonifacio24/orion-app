import 'package:dio/dio.dart';

import '../models/auth_models.dart';

class AuthDataSource {
  const AuthDataSource(this._dio);

  final Dio _dio;

  Future<AuthResponseModel> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/register', data: {
      'email': email,
      'userName': userName,
      'password': password,
      'confirmPassword': confirmPassword,
      'firstName': firstName,
      'lastName': lastName,
    });
    return AuthResponseModel.fromJson(response.data!);
  }

  Future<AuthResponseModel> login(String emailOrUserName, String password) async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/login', data: {
      'emailOrUserName': emailOrUserName,
      'password': password,
    });
    return AuthResponseModel.fromJson(response.data!);
  }

  Future<AuthResponseModel> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    return AuthResponseModel.fromJson(response.data!);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post<void>('/auth/forgot-password', data: {'email': email});
  }

  Future<AuthUserModel> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AuthUserModel.fromJson(response.data!);
  }
}