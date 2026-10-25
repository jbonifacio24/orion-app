import 'package:dio/dio.dart';

import '../../domain/entities/workshop_filters.dart';
import '../models/workshop_models.dart';

class WorkshopDataSource {
  const WorkshopDataSource(this._dio);
  final Dio _dio;

  Future<PagedWorkshopsModel> getWorkshops(WorkshopFilters filters, {int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>('/workshops', queryParameters: filters.toQuery(page: page));
    return PagedWorkshopsModel.fromJson(response.data!);
  }

  Future<WorkshopDetailModel> getWorkshopDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/workshops/$id');
    return WorkshopDetailModel.fromJson(response.data!);
  }

  Future<void> deleteWorkshop(String id) async {
    await _dio.delete<void>('/workshops/$id');
  }
}