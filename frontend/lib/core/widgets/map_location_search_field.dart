import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../di/injection.dart';
import '../network/api_client.dart';

class MapLocationSearchResult {
  const MapLocationSearchResult({required this.label, required this.location});

  final String label;
  final LatLng location;
}

typedef MapLocationLookup = Future<List<MapLocationSearchResult>> Function(
    String query);

class MapLocationSearchField extends StatefulWidget {
  const MapLocationSearchField({
    required this.onSelected,
    this.enabled = true,
    this.labelText = 'Buscar dirección o lugar',
    this.lookup,
    super.key,
  });

  final ValueChanged<MapLocationSearchResult> onSelected;
  final bool enabled;
  final String labelText;
  final MapLocationLookup? lookup;

  @override
  State<MapLocationSearchField> createState() => _MapLocationSearchFieldState();
}

class _MapLocationSearchFieldState extends State<MapLocationSearchField> {
  final _query = TextEditingController();
  Geocoding? _geocoding;
  List<MapLocationSearchResult> _results = const [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty || _isSearching || !widget.enabled) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _results = const [];
    });

    try {
      final lookup = widget.lookup ?? (kIsWeb ? _lookupWebAddress : _lookupAddress);
      final results = await lookup(query);
      if (!mounted) return;
      setState(() {
        _results = results.take(5).toList(growable: false);
        if (_results.isEmpty) _error = 'No encontramos esa ubicación.';
      });
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _error = error.response?.statusCode == 429
            ? 'Espera un momento antes de buscar otra ubicación.'
            : 'No se pudo buscar. Inténtalo de nuevo.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _error = 'No se pudo buscar. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<List<MapLocationSearchResult>> _lookupAddress(String query) async {
    final geocoding = _geocoding ??= Geocoding(locale: const Locale('es'));
    final locations = await geocoding.locationFromAddress(query);
    if (locations.isEmpty) return const [];

    return List.generate(locations.length, (index) {
      final location = locations[index];
      return MapLocationSearchResult(
        label:
            locations.length == 1 ? query : '$query - Resultado ${index + 1}',
        location: LatLng(location.latitude, location.longitude),
      );
    });
  }

  Future<List<MapLocationSearchResult>> _lookupWebAddress(String query) async {
    final response = await getIt<ApiClient>().dio.get<List<dynamic>>(
      '/geocoding/search',
      queryParameters: {'query': query},
    );

    return (response.data ?? const <dynamic>[]).map((item) {
      final place = Map<String, dynamic>.from(item as Map);
      return MapLocationSearchResult(
        label: place['label'] as String,
        location: LatLng(
          (place['latitude'] as num).toDouble(),
          (place['longitude'] as num).toDouble(),
        ),
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _query,
            enabled: widget.enabled && !_isSearching,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Buscar ubicación',
                onPressed: widget.enabled && !_isSearching ? _search : null,
                icon: _isSearching
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(result.label,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${result.location.latitude.toStringAsFixed(5)}, ${result.location.longitude.toStringAsFixed(5)}',
                    ),
                    onTap: () {
                      widget.onSelected(result);
                      setState(() {
                        _query.text = result.label;
                        _results = const [];
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ],
      );
}
