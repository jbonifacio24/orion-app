import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../domain/entities/motorcycle_image_upload.dart';
import '../models/motorcycle_models.dart';

class MotorcycleDataSource {
  const MotorcycleDataSource(this._dio);
  final Dio _dio;

  Future<List<MotorcycleModel>> getAll() async {
    final response = await _dio.get<List<dynamic>>('/motorcycles');
    return (response.data ?? const [])
        .map((item) => MotorcycleModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<MotorcycleModel> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/motorcycles/$id');
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<MotorcycleModel> create(MotorcycleRequestModel request) async {
    final response = await _dio.post<Map<String, dynamic>>('/motorcycles', data: request.toJson());
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<MotorcycleModel> update(String id, MotorcycleRequestModel request) async {
    final response = await _dio.put<Map<String, dynamic>>('/motorcycles/$id', data: request.toJson());
    return MotorcycleModel.fromJson(response.data!);
  }

  Future<void> delete(String id) => _dio.delete<void>('/motorcycles/$id');

  Future<void> deleteAsAdmin(String id) => _dio.delete<void>('/motorcycles/$id/admin');

  Future<MotorcycleImageModel> uploadImage(String id, MotorcycleImageUpload image) async {
    final extension = image.fileName.split('.').last.toLowerCase();
    final subtype = extension == 'png' ? 'png' : extension == 'webp' ? 'webp' : 'jpeg';
    final response = await _dio.post<Map<String, dynamic>>(
      '/motorcycles/$id/images',
      data: FormData.fromMap({'file': MultipartFile.fromBytes(image.bytes, filename: image.fileName, contentType: MediaType('image', subtype))}),
    );
    return MotorcycleImageModel.fromJson(response.data!);
  }

  Future<void> deleteImage(String id, String imageId) => _dio.delete<void>('/motorcycles/$id/images/$imageId');
}
