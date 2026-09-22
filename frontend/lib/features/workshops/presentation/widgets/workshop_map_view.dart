import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop.dart';
import '../models/workshop_map_marker_model.dart';

class WorkshopMapView extends StatefulWidget {
  const WorkshopMapView({required this.workshops, required this.onWorkshopTap, super.key});

  final List<Workshop> workshops;
  final ValueChanged<String> onWorkshopTap;

  @override
  State<WorkshopMapView> createState() => _WorkshopMapViewState();
}

class _WorkshopMapViewState extends State<WorkshopMapView> {
  final _mapController = MapController();
  bool _mapReady = false;
  String _markerSignature = '';

  @override
  void initState() {
    super.initState();
    _markerSignature = _signature(widget.workshops);
  }

  @override
  void didUpdateWidget(covariant WorkshopMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final signature = _signature(widget.workshops);
    if (signature == _markerSignature) return;
    _markerSignature = signature;
    _fitCameraIfReady();
  }

  @override
  Widget build(BuildContext context) {
    final markers = WorkshopMapMarkerModel.fromWorkshops(widget.workshops);
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: markers.isEmpty ? const LatLng(-12.0464, -77.0428) : LatLng(markers.first.latitude, markers.first.longitude),
            initialZoom: markers.length == 1 ? 14 : 5,
            onMapReady: () {
              _mapReady = true;
              _fitCameraIfReady();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.motohub.app',
            ),
            MarkerLayer(
              markers: markers
                  .map(
                    (marker) => Marker(
                      point: LatLng(marker.latitude, marker.longitude),
                      width: 48,
                      height: 56,
                      child: Semantics(
                        button: true,
                        label: marker.title,
                        child: IconButton(
                          tooltip: marker.title,
                          onPressed: () => widget.onWorkshopTap(marker.workshopId),
                          icon: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        if (markers.isEmpty)
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(widget.workshops.isEmpty ? AppLocalizations.noWorkshops : AppLocalizations.noWorkshopsWithLocation),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _fitCameraIfReady() {
    if (!_mapReady || !mounted) return;
    final markers = WorkshopMapMarkerModel.fromWorkshops(widget.workshops);
    if (markers.length < 2) {
      if (markers.length == 1) _mapController.move(LatLng(markers.first.latitude, markers.first.longitude), 14);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(markers.map((marker) => LatLng(marker.latitude, marker.longitude)).toList(growable: false)),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  String _signature(List<Workshop> workshops) => WorkshopMapMarkerModel.fromWorkshops(workshops).map((marker) => '${marker.workshopId}:${marker.latitude}:${marker.longitude}').join('|');
}