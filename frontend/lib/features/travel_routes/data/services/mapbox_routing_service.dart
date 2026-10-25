import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/environment_config.dart';
import '../../domain/services/routing_service.dart';

class MapboxRoutingService implements RoutingService {
  MapboxRoutingService(this._dio);

  final Dio _dio;

  @override
  Future<List<SuggestedRoute>> getRoutes({required LatLng start, required LatLng end}) async {
    final token = EnvironmentConfig.mapboxAccessToken;
    if (token.isEmpty) throw const MapboxConfigurationException();
    final response = await _dio.get<Map<String, dynamic>>(
      'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/${start.longitude},${start.latitude};${end.longitude},${end.latitude}',
      queryParameters: {
        'access_token': token,
        'alternatives': 'true',
        'overview': 'full',
        'geometries': 'geojson',
        'annotations': 'congestion,duration,speed',
      },
    );
    final rawRoutes = response.data?['routes'];
    if (rawRoutes is! List) throw const FormatException('Mapbox no devolvió rutas.');
    return rawRoutes.whereType<Map<String, dynamic>>().map(_parseRoute).whereType<SuggestedRoute>().toList(growable: false);
  }

  SuggestedRoute? _parseRoute(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final coordinates = geometry is Map<String, dynamic> ? geometry['coordinates'] : null;
    if (coordinates is! List) return null;
    final points = coordinates
        .whereType<List<dynamic>>()
        .where((point) => point.length >= 2 && point[0] is num && point[1] is num)
        .map((point) => LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()))
        .toList(growable: false);
    if (points.length < 2) return null;
    return SuggestedRoute(
      points: points,
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0,
      trafficLevel: _trafficLevel(json),
    );
  }

  String? _trafficLevel(Map<String, dynamic> route) {
    final congestion = <String>[];
    final legs = route['legs'];
    if (legs is List) {
      for (final leg in legs.whereType<Map<String, dynamic>>()) {
        final annotation = leg['annotation'];
        final values = annotation is Map<String, dynamic> ? annotation['congestion'] : null;
        if (values is List) congestion.addAll(values.whereType<String>());
      }
    }
    if (congestion.isEmpty) return null;
    final heavy = congestion.where((value) => value == 'heavy' || value == 'severe').length;
    if (heavy > congestion.length * .25) return 'Tráfico pesado';
    if (congestion.any((value) => value == 'moderate')) return 'Tráfico moderado';
    return 'Tráfico ligero';
  }
}

class MapboxConfigurationException implements Exception {
  const MapboxConfigurationException();

  @override
  String toString() => 'Configura MAPBOX_ACCESS_TOKEN para obtener rutas con tráfico.';
}
