import 'package:dio/dio.dart';

import '../../domain/entities/travel_route.dart';
import '../models/travel_route_model.dart';

class TravelRoutesDataSource {
  const TravelRoutesDataSource(this._dio);

  final Dio _dio;

  Future<List<TravelRouteModel>> getPublished() async {
    final response = await _dio.get<List<dynamic>>('/travel-routes');
    return (response.data ?? const []).map((item) => TravelRouteModel.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<TravelRouteModel> create(TravelRouteDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>('/travel-routes', data: {
      'title': draft.title,
      'description': draft.description,
      'startName': draft.startName,
      'endName': draft.endName,
      'startLatitude': draft.startLatitude,
      'startLongitude': draft.startLongitude,
      'endLatitude': draft.endLatitude,
      'endLongitude': draft.endLongitude,
      'pathJson': draft.pathJson,
      'departureAt': draft.departureAt.toUtc().toIso8601String(),
      'isPublished': true,
    });
    return TravelRouteModel.fromJson(response.data!);
  }

  Future<String> join(String routeId) async {
    final response = await _dio.post<Map<String, dynamic>>('/travel-routes/$routeId/join');
    return JoinTravelRouteModel.fromJson(response.data!).conversationId;
  }

  Future<void> delete(String routeId) async {
    await _dio.delete<void>('/travel-routes/$routeId');
  }
}