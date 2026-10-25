import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/environment_config.dart';
import '../../../../core/widgets/current_location_map_button.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/travel_route.dart';
import '../../domain/services/routing_service.dart';
import '../cubit/travel_routes_cubit.dart';

class CreateTravelRoutePage extends StatefulWidget {
  const CreateTravelRoutePage({required this.routingService, super.key});

  final RoutingService routingService;

  @override
  State<CreateTravelRoutePage> createState() => _CreateTravelRoutePageState();
}

class _CreateTravelRoutePageState extends State<CreateTravelRoutePage> {
  final _formKey = GlobalKey<FormState>();
  final _mapController = MapController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _startName = TextEditingController();
  final _endName = TextEditingController();
  LatLng? _startLocation;
  LatLng? _endLocation;
  String _selectionTarget = 'start';
  List<SuggestedRoute> _suggestedRoutes = const [];
  int _selectedRoute = 0;
  bool _loadingRoutes = false;
  int _routeRequestId = 0;
  DateTime _departureAt = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    for (final controller in [_title, _description, _startName, _endName]) {
      controller.dispose();
    }
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Crear ruta de viaje')),
        body: BlocBuilder<TravelRoutesCubit, TravelRoutesState>(
          builder: (context, state) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.error != null) Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                _field(_title, 'Título', required: true),
                _field(_description, 'Descripción', maxLines: 3),
                _field(_startName, 'Origen', required: true),
                _field(_endName, 'Destino', required: true),
                _locationPicker(),
                ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.schedule), title: const Text('Salida'), subtitle: Text(_formatDate(_departureAt)), onTap: state.isSubmitting ? null : _pickDate),
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: state.isSubmitting ? null : _submit, icon: state.isSubmitting ? const AppLoading(compact: true, color: Colors.white) : const Icon(Icons.publish), label: const Text('Publicar ruta')),
              ],
            ),
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, {bool required = false, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          enabled: !context.read<TravelRoutesCubit>().state.isSubmitting,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) return 'Campo requerido';
            return null;
          },
        ),
      );

  Widget _locationPicker() {
    final start = _startLocation;
    final end = _endLocation;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Selecciona los puntos de la ruta', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'start', label: Text('Elegir origen'), icon: Icon(Icons.trip_origin)),
              ButtonSegment(value: 'end', label: Text('Elegir destino'), icon: Icon(Icons.location_on)),
            ],
            selected: {_selectionTarget},
            onSelectionChanged: context.read<TravelRoutesCubit>().state.isSubmitting ? null : (selection) => setState(() => _selectionTarget = selection.first),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: start ?? end ?? const LatLng(-5.1945, -80.6328),
                      initialZoom: start == null && end == null ? 6 : 12,
                      onTap: context.read<TravelRoutesCubit>().state.isSubmitting ? null : (_, point) => _selectLocation(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: EnvironmentConfig.mapboxAccessToken.isEmpty
                            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                            : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${EnvironmentConfig.mapboxAccessToken}',
                        userAgentPackageName: 'com.motohub.app',
                      ),
                      if (_suggestedRoutes.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            for (var index = 0; index < _suggestedRoutes.length; index++)
                              Polyline(
                                points: _suggestedRoutes[index].points,
                                strokeWidth: index == _selectedRoute ? 6 : 3,
                                color: index == _selectedRoute ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
                              ),
                          ],
                        ),
                      MarkerLayer(markers: [
                        if (start != null) Marker(point: start, width: 48, height: 48, child: const Icon(Icons.trip_origin, color: Colors.green, size: 34)),
                        if (end != null) Marker(point: end, width: 48, height: 48, child: const Icon(Icons.location_on, color: Colors.red, size: 38)),
                      ]),
                      RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(EnvironmentConfig.mapboxAccessToken.isEmpty ? 'OpenStreetMap contributors' : 'Mapbox'),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: CurrentLocationMapButton(
                      mapController: _mapController,
                      zoom: 12,
                      onLocationFound: _selectLocation,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(start == null ? 'Origen: toca el mapa para seleccionarlo.' : 'Origen: ${_formatLocation(start)}'),
          Text(end == null ? 'Destino: selecciona "Elegir destino" y toca el mapa.' : 'Destino: ${_formatLocation(end)}'),
          if (_loadingRoutes) const Padding(padding: EdgeInsets.only(top: 12), child: Align(alignment: Alignment.centerLeft, child: AppLoading(compact: true))),
          if (_suggestedRoutes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Rutas sugeridas', style: Theme.of(context).textTheme.titleMedium),
            ...List.generate(_suggestedRoutes.length, (index) {
              final route = _suggestedRoutes[index];
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: index,
                groupValue: _selectedRoute,
                onChanged: context.read<TravelRoutesCubit>().state.isSubmitting ? null : (value) => setState(() => _selectedRoute = value ?? 0),
                title: Text('Ruta ${index + 1}'),
                subtitle: Text('${(route.distanceMeters / 1000).toStringAsFixed(1)} km - ${_formatDuration(route.durationSeconds)}${route.trafficLevel == null ? '' : ' - ${route.trafficLevel}'}'),
              );
            }),
          ],
          if (start != null || end != null)
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => setState(() { _startLocation = null; _endLocation = null; _selectionTarget = 'start'; _suggestedRoutes = const []; _selectedRoute = 0; }), icon: const Icon(Icons.clear), label: const Text('Limpiar selección'))),
        ],
      ),
    );
  }

  String _formatLocation(LatLng location) => '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  void _selectLocation(LatLng point) {
    setState(() {
      if (_selectionTarget == 'start') {
        _startLocation = point;
        _selectionTarget = 'end';
        _suggestedRoutes = const [];
      } else {
        _endLocation = point;
      }
    });
    if (_startLocation != null && _endLocation != null) _loadSuggestedRoutes();
  }

  Future<void> _loadSuggestedRoutes() async {
    final start = _startLocation;
    final end = _endLocation;
    if (start == null || end == null) return;
    final requestId = ++_routeRequestId;
    setState(() {
      _loadingRoutes = true;
      _suggestedRoutes = const [];
      _selectedRoute = 0;
    });
    try {
      final routes = await widget.routingService.getRoutes(start: start, end: end);
      if (!mounted || requestId != _routeRequestId) return;
      setState(() => _suggestedRoutes = routes);
    } catch (_) {
      if (mounted && requestId == _routeRequestId) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron obtener rutas sugeridas.')));
    } finally {
      if (mounted && requestId == _routeRequestId) setState(() => _loadingRoutes = false);
    }
  }


  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: _departureAt);
    if (!mounted || date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_departureAt));
    if (time == null) return;
    setState(() => _departureAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startLocation == null || _endLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona el origen y el destino en el mapa.')));
      return;
    }
    final selectedPoints = _suggestedRoutes.isNotEmpty ? _suggestedRoutes[_selectedRoute].points : [_startLocation!, _endLocation!];
    final path = jsonEncode(selectedPoints.map((point) => [point.latitude, point.longitude]).toList(growable: false));
    final created = await context.read<TravelRoutesCubit>().create(TravelRouteDraft(title: _title.text.trim(), description: _description.text.trim().isEmpty ? null : _description.text.trim(), startName: _startName.text.trim(), endName: _endName.text.trim(), startLatitude: _startLocation!.latitude, startLongitude: _startLocation!.longitude, endLatitude: _endLocation!.latitude, endLongitude: _endLocation!.longitude, pathJson: path, departureAt: _departureAt));
    if (mounted && created) Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
