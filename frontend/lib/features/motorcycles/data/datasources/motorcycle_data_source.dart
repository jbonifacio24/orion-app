import 'package:dio/dio.dart';

import '../models/motorcycle_models.dart';

class MotorcycleDataSource {
  const MotorcycleDataSource(this._dio);
  final Dio _dio;

  Future<List<MotorcycleModel>> getAll() async {
    final response = await _dio.get<List<dynamic>>('/api/motorcycles');
    return (response.data ?? const [])
        .map((item) => MotorcycleModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<MotorcycleModel> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/motorcycles/$id');
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<MotorcycleModel> create(MotorcycleRequestModel request) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/motorcycles', data: request.toJson());
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<MotorcycleModel> update(String id, MotorcycleRequestModel request) async {
    final response = await _dio.put<Map<String, dynamic>>('/api/motorcycles/$id', data: request.toJson());
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<void> delete(String id) => _dio.delete<void>('/api/motorcycles/$id');
}
