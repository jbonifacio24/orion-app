import 'package:dio/dio.dart';

import '../models/profile_models.dart';

class ProfileDataSource {
  const ProfileDataSource(this._dio);
  final Dio _dio;

  Future<ProfileModel> getCurrent() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/users/me');
    return ProfileModel.fromJson(response.data!);
  }

  Future<ProfileModel> update(UpdateProfileRequestModel request) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/users/me',
      data: request.toJson(),
    );
    return ProfileModel.fromJson(response.data!);
  }
}
