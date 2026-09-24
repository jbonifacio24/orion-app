import 'package:dio/dio.dart';

import '../../domain/entities/theft_report.dart';
import '../models/theft_report_models.dart';

class TheftDataSource {
  const TheftDataSource(this._dio);
  final Dio _dio;

  Future<PagedTheftReportsModel> getActiveReports({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/theft-reports', queryParameters: {'page': page, 'pageSize': pageSize});
    return PagedTheftReportsModel.fromJson(response.data!);
  }

  Future<TheftReportModel> getReport(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/theft-reports/$id');
    return TheftReportModel.fromJson(response.data!);
  }

  Future<PagedTheftReportsModel> getMyReports({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/theft-reports/mine', queryParameters: {'page': page, 'pageSize': pageSize});
    return PagedTheftReportsModel.fromJson(response.data!);
  }

  Future<TheftReportModel> createReport(CreateTheftReportInput input) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/theft-reports', data: CreateTheftReportRequestModel(input).toJson());
    return TheftReportModel.fromJson(response.data!);
  }

  Future<TheftReportModel> updateStatus(String id, TheftReportStatus status) async {
    final response = await _dio.patch<Map<String, dynamic>>('/api/theft-reports/$id/status', data: UpdateTheftReportStatusRequestModel(status).toJson());
    return TheftReportModel.fromJson(response.data!);
  }

}