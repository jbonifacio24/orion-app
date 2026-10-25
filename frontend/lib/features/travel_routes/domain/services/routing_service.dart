import 'package:latlong2/latlong.dart';

class SuggestedRoute {
  const SuggestedRoute({required this.points, required this.distanceMeters, required this.durationSeconds, this.trafficLevel});

  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final String? trafficLevel;
}

abstract interface class RoutingService {
  Future<List<SuggestedRoute>> getRoutes({required LatLng start, required LatLng end});
}
