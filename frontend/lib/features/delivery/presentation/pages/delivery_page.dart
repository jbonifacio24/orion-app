import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_loading.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../chat/presentation/cubit/conversations_cubit.dart';
import '../../../marketplace_transactions/domain/entities/product_transaction.dart';
import '../../../marketplace_transactions/presentation/cubit/product_transaction_cubit.dart';
import '../../../travel_routes/domain/services/routing_service.dart';
import '../cubit/delivery_cubit.dart';
import '../../domain/entities/delivery.dart';

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({this.transactionId, required this.routingService, super.key});
  final String? transactionId;
  final RoutingService routingService;

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final MapController _mapController = MapController();
  bool _mapReady = false;
  String? _routeKey;
  List<LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    final transactions = context.read<ProductTransactionCubit>();
    if (widget.transactionId == null) {
      transactions.loadMine();
      context.read<DeliveryCubit>().loadDriverDashboard();
    } else {
      transactions.load(widget.transactionId!);
      final authState = context.read<AuthCubit>().state;
      final userId = authState is AuthAuthenticated ? authState.user.id : '';
      context.read<DeliveryCubit>().load(widget.transactionId!, currentUserId: userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionState = context.watch<ProductTransactionCubit>().state;
    final deliveryState = context.watch<DeliveryCubit>().state;
    final selected = widget.transactionId == null ? null : transactionState.transaction;
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery')),
      body: BlocListener<DeliveryCubit, DeliveryState>(
        listenWhen: (previous, current) => previous.delivery?.driverLatitude != current.delivery?.driverLatitude || previous.delivery?.driverLongitude != current.delivery?.driverLongitude || previous.delivery?.id != current.delivery?.id,
        listener: (context, state) {
          _centerOnDriver(state.delivery);
          _loadRoute(state.delivery);
        },
        child: widget.transactionId == null
            ? _list(context, transactionState.items, deliveryState)
            : selected == null
                ? deliveryState.delivery == null
                    ? const AppLoading()
                    : _driverDetail(context, deliveryState)
                : _detail(context, selected, deliveryState),
      ),
    );
  }

  void _onMapReady() {
    _mapReady = true;
    _centerOnDriver(context.read<DeliveryCubit>().state.delivery);
  }

  void _centerOnDriver(Delivery? delivery) {
    if (!_mapReady || delivery?.driverLatitude == null || delivery?.driverLongitude == null) return;
    _mapController.move(LatLng(delivery!.driverLatitude!, delivery.driverLongitude!), 14);
  }

  Future<void> _loadRoute(Delivery? delivery) async {
    final pickupLatitude = delivery?.pickupLatitude;
    final pickupLongitude = delivery?.pickupLongitude;
    if (delivery == null || pickupLatitude == null || pickupLongitude == null) return;
    final key = '${delivery.id}:$pickupLatitude:$pickupLongitude:${delivery.destinationLatitude}:${delivery.destinationLongitude}';
    if (_routeKey == key) return;
    _routeKey = key;
    try {
      final routes = await widget.routingService.getRoutes(
        start: LatLng(pickupLatitude, pickupLongitude),
        end: LatLng(delivery.destinationLatitude, delivery.destinationLongitude),
      );
      if (mounted && _routeKey == key) setState(() => _routePoints = routes.isEmpty ? [LatLng(pickupLatitude, pickupLongitude), LatLng(delivery.destinationLatitude, delivery.destinationLongitude)] : routes.first.points);
    } catch (_) {
      if (mounted && _routeKey == key) setState(() => _routePoints = [LatLng(pickupLatitude, pickupLongitude), LatLng(delivery.destinationLatitude, delivery.destinationLongitude)]);
    }
  }

  Widget _list(BuildContext context, List<ProductTransaction> items, DeliveryState deliveryState) {
    final eligible = items.where((item) => item.status == ProductTransactionStatus.paid || item.status == ProductTransactionStatus.delivered).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Marketplace Delivery', style: Theme.of(context).textTheme.headlineSmall),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.delivery_dining_outlined),
        title: const Text('Ofrecerme como conductor'),
        subtitle: Text(deliveryState.isDriverAvailable ? 'Tu ubicación está visible para búsquedas cercanas.' : 'Completa tu perfil y los datos de una motocicleta para activarlo.'),
        value: deliveryState.isDriverAvailable,
        onChanged: deliveryState.submitting || (deliveryState.driverEligibility?.isEligible != true && !deliveryState.isDriverAvailable)
            ? null
            : (value) => context.read<DeliveryCubit>().setDriverAvailability(value),
      ),
      if (deliveryState.driverEligibility case final eligibility? when !eligibility.isEligible) _driverEligibilityCard(context, eligibility),
      if (deliveryState.assignedDeliveries.isNotEmpty) ...[
        const Divider(),
        Text('Entregas asignadas', style: Theme.of(context).textTheme.titleLarge),
        ...deliveryState.assignedDeliveries.map((delivery) => Card(child: ListTile(leading: const Icon(Icons.route_outlined), title: Text('Operación ${delivery.transactionId.substring(0, 8)}'), subtitle: Text(_statusLabel(delivery.status)), trailing: const Icon(Icons.chevron_right), onTap: () => context.pushNamed('delivery-detail', pathParameters: {'id': delivery.transactionId})))),
      ],
      const Divider(),
      Text('Tus compras y ventas', style: Theme.of(context).textTheme.titleLarge),
      if (eligible.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No tienes operaciones pagadas listas para Delivery.')),
      ...eligible.map((item) => Card(child: ListTile(leading: const Icon(Icons.delivery_dining_outlined), title: Text('Operación ${item.id.substring(0, 8)}'), subtitle: Text(_transactionStatus(item.status)), trailing: const Icon(Icons.chevron_right), onTap: () => context.pushNamed('delivery-detail', pathParameters: {'id': item.id})))),
    ]);
  }

  Widget _driverEligibilityCard(BuildContext context, DeliveryDriverEligibility eligibility) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Requisitos para conducir', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _eligibilityItem(eligibility.emailConfirmed, 'Correo electrónico confirmado'),
            _eligibilityItem(eligibility.hasFullName, 'Nombre y apellidos completos en tu perfil'),
            _eligibilityItem(eligibility.hasPhoneNumber, 'Teléfono agregado a tu perfil'),
            _eligibilityItem(eligibility.hasQualifiedMotorcycle, 'Una moto con marca, modelo, año, matrícula y VIN'),
            const SizedBox(height: 4),
            Text('Estos requisitos comprueban que tus datos estén completos en MotoHub; no constituyen una verificación oficial de identidad o propiedad.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (!eligibility.emailConfirmed)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(onPressed: () => _confirmDriverEmail(context), icon: const Icon(Icons.mark_email_read_outlined), label: const Text('Confirmar correo')),
              ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: () => context.pushNamed(RouteNames.profileEdit), icon: const Icon(Icons.person_outline), label: const Text('Editar perfil')),
              OutlinedButton.icon(onPressed: () => context.pushNamed(RouteNames.motorcycles), icon: const Icon(Icons.two_wheeler_outlined), label: const Text('Mis motocicletas')),
            ]),
          ]),
        ),
      );

  Future<void> _confirmDriverEmail(BuildContext context) async {
    final tokenController = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar correo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ingresa el token enviado a tu correo registrado.'),
          const SizedBox(height: 12),
          TextField(controller: tokenController, autofocus: true, decoration: const InputDecoration(labelText: 'Token de confirmación')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, tokenController.text.trim()), child: const Text('Confirmar')),
        ],
      ),
    );
    tokenController.dispose();
    if (token == null || token.isEmpty || !context.mounted) return;
    try {
      await context.read<AuthCubit>().confirmEmail(token);
      if (!context.mounted) return;
      await context.read<DeliveryCubit>().loadDriverDashboard();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correo confirmado.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo confirmar el correo. Revisa el token e inténtalo de nuevo.')));
    }
  }

  Widget _eligibilityItem(bool complete, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(complete ? Icons.check_circle_outline : Icons.radio_button_unchecked, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ]),
      );

  Widget _driverDetail(BuildContext context, DeliveryState state) => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Entrega asignada', style: Theme.of(context).textTheme.headlineSmall),
        Text('Operación ${state.delivery!.transactionId.substring(0, 8)}'),
        if (state.error != null) Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 16),
        _trackingCard(context, state.delivery!),
      ]);

  Widget _detail(BuildContext context, ProductTransaction transaction, DeliveryState state) {
    final delivery = state.delivery;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Seguimiento de Delivery', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('Operación ${transaction.id.substring(0, 8)}'),
      if (state.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 20),
      _contactButton(context, transaction),
      const SizedBox(height: 12),
      if (state.loading)
        const AppLoading()
      else if (delivery != null)
        _trackingCard(context, delivery)
      else if (transaction.status == ProductTransactionStatus.paid)
        _requestCard(context, transaction, state)
      else
        const Text('Esta operación ya fue marcada como entregada y no admite una nueva solicitud de Delivery.'),
    ]);
  }

  Widget _contactButton(BuildContext context, ProductTransaction transaction) {
    final authState = context.watch<AuthCubit>().state;
    final userId = authState is AuthAuthenticated ? authState.user.id : '';
    final isSeller = transaction.sellerUserId == userId;
    final isBuyer = transaction.buyerUserId == userId;
    if (!isSeller && !isBuyer) return const SizedBox.shrink();
    final recipientId = isSeller ? transaction.buyerUserId : transaction.sellerUserId;
    final label = isSeller ? 'Contactar comprador' : 'Contactar vendedor';
    final conversations = context.watch<ConversationsCubit>();
    return OutlinedButton.icon(
      onPressed: conversations.state.isCreating ? null : () => _openChat(context, recipientId),
      icon: const Icon(Icons.chat_bubble_outline),
      label: Text(conversations.state.isCreating ? 'Abriendo chat...' : label),
    );
  }

  Future<void> _openChat(BuildContext context, String recipientId) async {
    final conversations = context.read<ConversationsCubit>();
    final conversation = await conversations.getOrCreateDirect(recipientId);
    if (!context.mounted) return;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(conversations.state.actionFailure ?? 'No se pudo abrir el chat.')));
      return;
    }
    context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversation.id});
  }

  Widget _requestCard(BuildContext context, ProductTransaction transaction, DeliveryState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.delivery_dining_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Buscaremos conductores disponibles cerca del punto de recojo del producto. El destino será tu ubicación actual.'),
            const SizedBox(height: 16),
            if (state.nearbyDrivers.isEmpty)
              FilledButton.icon(onPressed: state.submitting ? null : () => context.read<DeliveryCubit>().searchNearbyDrivers(transaction.id), icon: const Icon(Icons.search), label: const Text('Buscar conductores cercanos')),
            if (state.nearbyDrivers.isNotEmpty) ...[
              Text('Conductores cercanos', style: Theme.of(context).textTheme.titleMedium),
              ...state.nearbyDrivers.map((driver) => ListTile(
                    leading: Icon(state.selectedDriverUserId == driver.userId ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    title: Text(driver.displayName),
                    subtitle: Text('${driver.distanceInKm.toStringAsFixed(1)} km del punto de recojo'),
                    onTap: state.submitting ? null : () => context.read<DeliveryCubit>().selectDriver(driver.userId),
                  )),
              FilledButton.icon(onPressed: state.submitting || state.selectedDriverUserId == null ? null : () => context.read<DeliveryCubit>().request(transaction.id, driverUserId: state.selectedDriverUserId!), icon: const Icon(Icons.send_outlined), label: const Text('Solicitar a este conductor')),
              TextButton.icon(onPressed: state.submitting ? null : () => context.read<DeliveryCubit>().searchNearbyDrivers(transaction.id), icon: const Icon(Icons.refresh), label: const Text('Actualizar conductores')),
            ],
          ]),
        ),
      );

  Widget _trackingCard(BuildContext context, Delivery delivery) {
    final colorScheme = Theme.of(context).colorScheme;
    final deliveryState = context.watch<DeliveryCubit>().state;
    final authState = context.read<AuthCubit>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';
    final isDriver = currentUserId == delivery.driverUserId;
    final hasDriver = delivery.driverLatitude != null && delivery.driverLongitude != null;
    final distance = hasDriver ? _distance(delivery.driverLatitude!, delivery.driverLongitude!, delivery.destinationLatitude, delivery.destinationLongitude) : null;
    final center = hasDriver ? LatLng(delivery.driverLatitude!, delivery.driverLongitude!) : LatLng(delivery.destinationLatitude, delivery.destinationLongitude);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(child: ListTile(leading: Icon(_statusIcon(delivery.status)), title: Text(_statusLabel(delivery.status)), subtitle: Text(distance == null ? 'Esperando ubicación del conductor' : '${distance.toStringAsFixed(1)} km del destino${deliveryState.isRealtimeConnected ? ' · En vivo' : ' · Actualizando ubicación'}'))),
      SizedBox(
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14, onMapReady: _onMapReady),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.motohub.app'),
              if (_routePoints.length >= 2) PolylineLayer(polylines: [Polyline(points: _routePoints, strokeWidth: 4, color: colorScheme.primary)]),
              MarkerLayer(markers: [
                if (hasDriver) Marker(point: LatLng(delivery.driverLatitude!, delivery.driverLongitude!), width: 48, height: 48, child: Icon(Icons.delivery_dining, color: colorScheme.primary, size: 38)),
                if (delivery.pickupLatitude != null && delivery.pickupLongitude != null) Marker(point: LatLng(delivery.pickupLatitude!, delivery.pickupLongitude!), width: 48, height: 48, child: const Icon(Icons.store_mall_directory_outlined, color: Colors.blue, size: 34)),
                Marker(point: LatLng(delivery.destinationLatitude, delivery.destinationLongitude), width: 48, height: 48, child: const Icon(Icons.location_pin, color: Colors.red, size: 38)),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      if (distance != null) Text('ETA aproximada: ${math.max(1, (distance / 25 * 60).ceil())} min', style: Theme.of(context).textTheme.titleMedium),
      if (isDriver && delivery.status != DeliveryStatus.delivered) OutlinedButton.icon(onPressed: context.watch<DeliveryCubit>().state.submitting ? null : () => context.read<DeliveryCubit>().complete(), icon: const Icon(Icons.check_circle_outline), label: const Text('Confirmar entrega')),
    ]);
  }

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  IconData _statusIcon(DeliveryStatus status) => switch (status) { DeliveryStatus.requested => Icons.schedule, DeliveryStatus.inTransit => Icons.delivery_dining, DeliveryStatus.near => Icons.near_me, DeliveryStatus.delivered => Icons.check_circle, DeliveryStatus.cancelled => Icons.cancel };
  String _statusLabel(DeliveryStatus status) => switch (status) { DeliveryStatus.requested => 'Solicitud recibida', DeliveryStatus.inTransit => 'Movilidad en camino', DeliveryStatus.near => 'La movilidad está cerca', DeliveryStatus.delivered => 'Entrega completada', DeliveryStatus.cancelled => 'Delivery cancelado' };
  String _transactionStatus(ProductTransactionStatus status) => status == ProductTransactionStatus.paid ? 'Lista para solicitar' : 'En proceso de entrega';
}
