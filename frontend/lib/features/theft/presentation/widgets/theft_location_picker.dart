import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/current_location_map_button.dart';
import '../../../../core/widgets/map_location_search_field.dart';

class TheftLocationPicker extends StatefulWidget {
  const TheftLocationPicker({this.initialLocation, super.key});

  final LatLng? initialLocation;

  @override
  State<TheftLocationPicker> createState() => _TheftLocationPickerState();
}

class _TheftLocationPickerState extends State<TheftLocationPicker> {
  final MapController _mapController = MapController();
  late LatLng _selectedLocation =
      widget.initialLocation ?? const LatLng(-12.0464, -77.0428);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Seleccionar ubicación'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, _selectedLocation),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Usar lugar'),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: widget.initialLocation == null ? 5 : 15,
                onTap: (_, point) => setState(() => _selectedLocation = point),
              ),
              children: [
                TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.motohub.app'),
                MarkerLayer(markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 56,
                    height: 64,
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.red, size: 52),
                  ),
                ]),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('OpenStreetMap contributors')
                ]),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: MapLocationSearchField(
                    onSelected: (result) {
                      setState(() => _selectedLocation = result.location);
                      _mapController.move(result.location, 15);
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 88,
              child: CurrentLocationMapButton(
                mapController: _mapController,
                onLocationFound: (location) =>
                    setState(() => _selectedLocation = location),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}  |  Lon: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      );
}
