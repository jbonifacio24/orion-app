import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CurrentLocationMapButton extends StatefulWidget {
  const CurrentLocationMapButton({
    required this.mapController,
    required this.onLocationFound,
    this.zoom = 16,
    super.key,
  });

  final MapController mapController;
  final ValueChanged<LatLng> onLocationFound;
  final double zoom;

  @override
  State<CurrentLocationMapButton> createState() => _CurrentLocationMapButtonState();
}

class _CurrentLocationMapButtonState extends State<CurrentLocationMapButton> {
  bool _isLocating = false;

  Future<void> _useCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Activa los servicios de ubicación e inténtalo de nuevo.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showMessage('Permite el acceso a tu ubicación para centrar el mapa.');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      widget.mapController.move(location, widget.zoom);
      widget.onLocationFound(location);
    } catch (_) {
      _showMessage('No se pudo obtener tu ubicación. Revisa los permisos e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton.small(
        tooltip: 'Usar mi ubicación actual',
        onPressed: _isLocating ? null : _useCurrentLocation,
        child: _isLocating
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location_rounded),
      );
}