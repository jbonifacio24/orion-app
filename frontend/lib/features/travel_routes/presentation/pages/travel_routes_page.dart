import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../chat/presentation/cubit/conversations_cubit.dart';
import '../../domain/entities/travel_route.dart';
import '../cubit/travel_routes_cubit.dart';

class TravelRoutesPage extends StatefulWidget {
  const TravelRoutesPage({super.key});

  @override
  State<TravelRoutesPage> createState() => _TravelRoutesPageState();
}

class _TravelRoutesPageState extends State<TravelRoutesPage> {
  @override
  void initState() {
    super.initState();
    context.read<TravelRoutesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthCubit, bool>((cubit) => cubit.state is AuthAuthenticated && (cubit.state as AuthAuthenticated).user.roles.any((role) => role.toLowerCase() == 'admin'));
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas de viaje'), actions: [if (isAdmin) IconButton(tooltip: 'Crear ruta', onPressed: () => context.pushNamed(RouteNames.travelRouteCreate), icon: const Icon(Icons.add_road))]),
      body: BlocConsumer<TravelRoutesCubit, TravelRoutesState>(
        listener: (context, state) {
          if (state.error != null && !state.isLoading) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error!)));
          if (state.actionMessage != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.actionMessage!)));
        },
        builder: (context, state) {
          if (state.isLoading && state.items.isEmpty) return const AppLoading();
          if (state.items.isEmpty) return _empty(context, state.error);
          return RefreshIndicator(onRefresh: context.read<TravelRoutesCubit>().load, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.items.length, itemBuilder: (context, index) => _RouteCard(route: state.items[index], isAdmin: isAdmin)));
        },
      ),
    );
  }

  Widget _empty(BuildContext context, String? error) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.route_outlined, size: 64, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 12), Text(error ?? 'Todavía no hay rutas publicadas.', textAlign: TextAlign.center), const SizedBox(height: 16), OutlinedButton.icon(onPressed: context.read<TravelRoutesCubit>().load, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])));
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.isAdmin});

  final TravelRoute route;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final path = _pathPoints(route);
    final center = LatLng(route.startLatitude, route.startLongitude);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 220, child: FlutterMap(options: MapOptions(initialCenter: center, initialZoom: 7), children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.motohub.app'), if (path.isNotEmpty) PolylineLayer(polylines: [Polyline(points: path, strokeWidth: 4, color: Theme.of(context).colorScheme.primary)]), MarkerLayer(markers: [Marker(point: LatLng(route.startLatitude, route.startLongitude), width: 40, height: 40, child: const Icon(Icons.trip_origin, color: Colors.green, size: 28)), Marker(point: LatLng(route.endLatitude, route.endLongitude), width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 32))])])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: Text(route.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), if (isAdmin) IconButton(tooltip: 'Eliminar ruta', onPressed: () => _delete(context), icon: const Icon(Icons.delete_outline))]), if (route.description?.trim().isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text(route.description!)), const SizedBox(height: 10), Text('${route.startName}  →  ${route.endName}', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), Text('Salida: ${_formatDate(route.departureAt)}'), const SizedBox(height: 12), FilledButton.icon(onPressed: () => _join(context), icon: const Icon(Icons.forum_outlined), label: const Text('Unirse al chat de la ruta')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => _track(context), icon: const Icon(Icons.people_alt_outlined), label: const Text('Ver ubicación del grupo'))])),
      ]),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Eliminar esta ruta?'), content: const Text('La ruta dejará de aparecer y no se podrán iniciar nuevas participaciones.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))])) ?? false;
    if (!confirmed || !context.mounted) return;
    await context.read<TravelRoutesCubit>().delete(route);
  }

  Future<void> _join(BuildContext context) async {
    final conversationId = await context.read<TravelRoutesCubit>().join(route);
    if (!context.mounted || conversationId == null) return;
    await context.read<ConversationsCubit>().refresh();
    if (context.mounted) context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversationId});
  }

  Future<void> _track(BuildContext context) async {
    final conversationId = await context.read<TravelRoutesCubit>().join(route);
    if (!context.mounted || conversationId == null) return;
    context.pushNamed(RouteNames.travelRouteTrack, pathParameters: {'routeId': route.id}, extra: route);
  }

  List<LatLng> _pathPoints(TravelRoute route) {
    try {
      final raw = jsonDecode(route.pathJson);
      if (raw is! List) return const [];
      return raw.map<LatLng?>((item) {
        if (item is List && item.length >= 2 && item[0] is num && item[1] is num) return LatLng((item[0] as num).toDouble(), (item[1] as num).toDouble());
        if (item is Map && item['latitude'] is num && item['longitude'] is num) return LatLng((item['latitude'] as num).toDouble(), (item['longitude'] as num).toDouble());
        return null;
      }).whereType<LatLng>().toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}