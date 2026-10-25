import 'package:latlong2/latlong.dart';

import '../../domain/services/routing_service.dart';

class GoogleRoutingService implements RoutingService {
  const GoogleRoutingService();

  @override
  Future<List<SuggestedRoute>> getRoutes({required LatLng start, required LatLng end}) {
    throw UnimplementedError('La implementación de Google Routes se puede conectar sin cambiar la pantalla ni el contrato RoutingService.');
  }
}
