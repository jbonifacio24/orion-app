import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/repositories/chat_realtime_repository.dart';
import '../../domain/entities/travel_route.dart';

class TravelRouteTrackingPage extends StatefulWidget {
  const TravelRouteTrackingPage({required this.route, required this.realtime, super.key});

  final TravelRoute route;
  final ChatRealtimeRepository realtime;

  @override
  State<TravelRouteTrackingPage> createState() => _TravelRouteTrackingPageState();
}

class _TravelRouteTrackingPageState extends State<TravelRouteTrackingPage> {
  final _locations = <String, RouteLocation>{};
  StreamSubscription<RouteLocation>? _locationSubscription;
  Timer? _timer;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    try {
      await widget.realtime.start();
      await widget.realtime.joinConversation(widget.route.conversationId);
      _locationSubscription = widget.realtime.routeLocations.listen((location) {
        if (location.conversationId != widget.route.conversationId || !mounted) return;
        setState(() => _locations[location.userId] = location);
      });
      await _sendLocation();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
      if (mounted) setState(() => _sharing = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el grupo de la ruta.');
    }
  }

  Future<void> _sendLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _error = 'Activa la ubicación para compartir tu posición.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _error = 'Se necesita permiso de ubicación para compartirla.');
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    await widget.realtime.publishRouteLocation(widget.route.conversationId, latitude: position.latitude, longitude: position.longitude);
  }

  Future<void> _stopSharing() async {
    _timer?.cancel();
    _timer = null;
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await widget.realtime.leaveConversation(widget.route.conversationId);
    if (mounted) setState(() => _sharing = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    widget.realtime.leaveConversation(widget.route.conversationId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final routePoints = _pathPoints(widget.route);
    final center = routePoints.isEmpty ? LatLng(widget.route.startLatitude, widget.route.startLongitude) : routePoints[routePoints.length ~/ 2];
    return Scaffold(
      appBar: AppBar(title: Text(widget.route.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          Card(child: SwitchListTile(secondary: Icon(_sharing ? Icons.location_on : Icons.location_off), title: Text(_sharing ? 'Compartiendo ubicación' : 'Ubicación pausada'), subtitle: Text('${_locations.length} participante(s) visibles'), value: _sharing, onChanged: (value) => value ? _startTracking() : _stopSharing())),
          const SizedBox(height: 12),
          SizedBox(
            height: 380,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 10),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.motohub.app'),
                  if (routePoints.length > 1) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 4, color: Theme.of(context).colorScheme.primary)]),
                  MarkerLayer(markers: [
                    ..._locations.values.map((location) => Marker(point: LatLng(location.latitude, location.longitude), width: 100, height: 58, child: Column(children: [Icon(Icons.motorcycle, color: colorScheme.primary, size: 32), Container(color: colorScheme.surface, padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(location.displayName, style: TextStyle(color: colorScheme.onSurface), overflow: TextOverflow.ellipsis))]))),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._locations.values.map((location) => ListTile(leading: const Icon(Icons.motorcycle), title: Text(location.displayName), subtitle: Text('${_distanceToStart(location).toStringAsFixed(1)} km desde el origen'))),
        ],
      ),
    );
  }

  double _distanceToStart(RouteLocation location) {
    const radius = 6371.0;
    final lat1 = widget.route.startLatitude * math.pi / 180;
    final lat2 = location.latitude * math.pi / 180;
    final dLat = lat2 - lat1;
    final dLon = (location.longitude - widget.route.startLongitude) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  List<LatLng> _pathPoints(TravelRoute route) {
    try {
      final raw = jsonDecode(route.pathJson);
      if (raw is! List) return const [];
      return raw.whereType<List<dynamic>>().where((item) => item.length >= 2 && item[0] is num && item[1] is num).map((item) => LatLng((item[0] as num).toDouble(), (item[1] as num).toDouble())).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
