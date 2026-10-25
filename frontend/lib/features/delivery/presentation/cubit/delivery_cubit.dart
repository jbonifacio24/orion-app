import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../domain/repositories/delivery_realtime_repository.dart';

class DeliveryState {
  const DeliveryState({this.delivery, this.nearbyDrivers = const [], this.assignedDeliveries = const [], this.driverEligibility, this.selectedDriverUserId, this.destinationLatitude, this.destinationLongitude, this.isDriverAvailable = false, this.loading = false, this.submitting = false, this.isRealtimeConnected = false, this.error});
  final Delivery? delivery;
  final List<NearbyDeliveryDriver> nearbyDrivers;
  final List<Delivery> assignedDeliveries;
  final DeliveryDriverEligibility? driverEligibility;
  final String? selectedDriverUserId;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final bool isDriverAvailable;
  final bool loading;
  final bool submitting;
  final bool isRealtimeConnected;
  final String? error;

  DeliveryState copyWith({Delivery? delivery, List<NearbyDeliveryDriver>? nearbyDrivers, List<Delivery>? assignedDeliveries, DeliveryDriverEligibility? driverEligibility, String? selectedDriverUserId, double? destinationLatitude, double? destinationLongitude, bool? isDriverAvailable, bool? loading, bool? submitting, bool? isRealtimeConnected, String? error, bool clearSelectedDriver = false, bool clearDestination = false, bool clearError = false}) => DeliveryState(
        delivery: delivery ?? this.delivery,
        nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
        assignedDeliveries: assignedDeliveries ?? this.assignedDeliveries,
        driverEligibility: driverEligibility ?? this.driverEligibility,
        selectedDriverUserId: clearSelectedDriver ? null : selectedDriverUserId ?? this.selectedDriverUserId,
        destinationLatitude: clearDestination ? null : destinationLatitude ?? this.destinationLatitude,
        destinationLongitude: clearDestination ? null : destinationLongitude ?? this.destinationLongitude,
        isDriverAvailable: isDriverAvailable ?? this.isDriverAvailable,
        loading: loading ?? this.loading,
        submitting: submitting ?? this.submitting,
        isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
        error: clearError ? null : error ?? this.error,
      );
}

class DeliveryCubit extends Cubit<DeliveryState> {
  DeliveryCubit(this._repository, [this._realtime]) : super(const DeliveryState()) {
    _deliverySubscription = _realtime?.updates.listen(_onRealtimeUpdate);
    _connectionSubscription = _realtime?.connectionStates.listen(_onConnectionState);
  }

  final DeliveryRepository _repository;
  final DeliveryRealtimeRepository? _realtime;
  Timer? _timer;
  Timer? _fallbackTimer;
  Timer? _availabilityTimer;
  String? _transactionId;
  bool _isDriver = false;
  StreamSubscription<Delivery>? _deliverySubscription;
  StreamSubscription<DeliveryRealtimeConnectionState>? _connectionSubscription;

  Future<void> load(String transactionId, {required String currentUserId}) async {
    if (_transactionId != null && _transactionId != transactionId) {
      _timer?.cancel();
      await _realtime?.leaveDelivery(_transactionId!);
    }
    _transactionId = transactionId;
    _isDriver = false;
    emit(state.copyWith(loading: true, isRealtimeConnected: false, clearError: true));
    try {
      final delivery = await _repository.get(transactionId);
      _isDriver = delivery.driverUserId == currentUserId;
      emit(state.copyWith(delivery: delivery, loading: false));
      await _connectRealtime(transactionId);
      if (_isDriver) {
        unawaited(_sendLocation());
        _startLocationUpdates();
      }
    } catch (error) {
      emit(state.copyWith(loading: false, error: ErrorMapper.from(error).message));
      _startFallbackPolling();
    }
  }

  Future<void> loadDriverDashboard() async {
    try {
      final eligibility = await _repository.getDriverEligibility();
      final availability = await _repository.getDriverAvailability();
      final assigned = await _repository.getAssigned();
      emit(state.copyWith(driverEligibility: eligibility, isDriverAvailable: availability, assignedDeliveries: assigned, clearError: true));
      if (availability && (!eligibility.isEligible || assigned.isNotEmpty)) {
        await _repository.updateDriverAvailability(isAvailable: false);
        emit(state.copyWith(isDriverAvailable: false));
      } else if (availability) {
        await _refreshAvailableLocation();
        if (state.isDriverAvailable) _startAvailabilityUpdates();
      }
    } catch (error) {
      emit(state.copyWith(error: ErrorMapper.from(error).message));
    }
  }

  Future<bool> setDriverAvailability(bool isAvailable) async {
    if (!isAvailable) {
      final disabled = await _run(() async {
        final available = await _repository.updateDriverAvailability(isAvailable: false);
        _availabilityTimer?.cancel();
        emit(state.copyWith(isDriverAvailable: available, submitting: false, clearError: true));
      });
      return disabled && !state.isDriverAvailable;
    }
    if (state.driverEligibility?.isEligible != true) {
      emit(state.copyWith(error: 'Completa los requisitos de tu perfil y motocicleta antes de ofrecerte como conductor.'));
      return false;
    }
    final position = await _currentPosition();
    if (position == null) return false;
    return _run(() async {
      final available = await _repository.updateDriverAvailability(latitude: position.latitude, longitude: position.longitude, isAvailable: isAvailable);
      emit(state.copyWith(isDriverAvailable: available, submitting: false, clearError: true));
      if (available) _startAvailabilityUpdates();
    });
  }

  void _startAvailabilityUpdates() {
    _availabilityTimer?.cancel();
    _availabilityTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshAvailableLocation());
  }

  Future<void> _refreshAvailableLocation() async {
    if (!state.isDriverAvailable || isClosed) return;
    final position = await _currentPosition();
    if (position == null) {
      await _repository.updateDriverAvailability(isAvailable: false);
      _availabilityTimer?.cancel();
      if (!isClosed) emit(state.copyWith(isDriverAvailable: false));
      return;
    }
    try {
      final available = await _repository.updateDriverAvailability(latitude: position.latitude, longitude: position.longitude, isAvailable: true);
      if (!available) {
        _availabilityTimer?.cancel();
        emit(state.copyWith(isDriverAvailable: false));
      }
    } catch (_) {
      _availabilityTimer?.cancel();
      emit(state.copyWith(isDriverAvailable: false));
    }
  }

  Future<bool> searchNearbyDrivers(String transactionId) async {
    final position = await _currentPosition();
    if (position == null) return false;
    return _run(() async {
      final drivers = await _repository.getNearbyDrivers(transactionId);
      emit(state.copyWith(nearbyDrivers: drivers, destinationLatitude: position.latitude, destinationLongitude: position.longitude, clearSelectedDriver: true, submitting: false, clearError: true));
      if (drivers.isEmpty) emit(state.copyWith(error: 'No hay conductores disponibles cerca del punto de recojo.'));
    });
  }

  void selectDriver(String userId) => emit(state.copyWith(selectedDriverUserId: userId, clearError: true));

  Future<bool> request(String transactionId, {required String driverUserId}) async {
    final latitude = state.destinationLatitude;
    final longitude = state.destinationLongitude;
    if (latitude == null || longitude == null) {
      emit(state.copyWith(error: 'Busca conductores para confirmar tu ubicación de destino.'));
      return false;
    }
    final requested = await _run(() async => emit(state.copyWith(delivery: await _repository.request(transactionId, latitude: latitude, longitude: longitude, driverUserId: driverUserId), submitting: false, clearError: true)));
    if (requested && state.delivery != null) await _connectRealtime(transactionId);
    return requested;
  }

  Future<bool> complete() async {
    final transactionId = _transactionId;
    if (transactionId == null) return false;
    return _run(() async => emit(state.copyWith(delivery: await _repository.complete(transactionId), submitting: false, clearError: true)));
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.submitting) return false;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await action();
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: ErrorMapper.from(error).message));
      return false;
    }
  }

  void _startLocationUpdates() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _sendLocation());
  }

  Future<void> _connectRealtime(String transactionId) async {
    final realtime = _realtime;
    if (realtime == null) {
      _startFallbackPolling();
      return;
    }
    try {
      await realtime.start();
      await realtime.joinDelivery(transactionId);
    } catch (_) {
      emit(state.copyWith(isRealtimeConnected: false));
      _startFallbackPolling();
    }
  }

  void _onRealtimeUpdate(Delivery delivery) {
    if (isClosed || delivery.transactionId != _transactionId) return;
    _fallbackTimer?.cancel();
    emit(state.copyWith(delivery: delivery, isRealtimeConnected: true));
    if (delivery.status == DeliveryStatus.delivered) _timer?.cancel();
  }

  void _onConnectionState(DeliveryRealtimeConnectionState connectionState) {
    if (isClosed) return;
    final connected = connectionState == DeliveryRealtimeConnectionState.connected;
    emit(state.copyWith(isRealtimeConnected: connected));
    if (connected) {
      _fallbackTimer?.cancel();
    } else if (connectionState == DeliveryRealtimeConnectionState.disconnected || connectionState == DeliveryRealtimeConnectionState.failed) {
      _startFallbackPolling();
    }
  }

  void _startFallbackPolling() {
    if (_transactionId == null || state.delivery == null || _fallbackTimer?.isActive == true) return;
    _fallbackTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      final transactionId = _transactionId;
      if (transactionId == null || isClosed) return;
      try {
        final delivery = await _repository.get(transactionId);
        if (transactionId == _transactionId && !isClosed) emit(state.copyWith(delivery: delivery));
      } catch (_) {}
    });
  }

  Future<void> _sendLocation() async {
    final current = state.delivery;
    final transactionId = _transactionId;
    if (!_isDriver || current == null || transactionId == null || current.status == DeliveryStatus.delivered) return;
    final position = await _currentPosition();
    if (position == null) return;
    try {
      emit(state.copyWith(delivery: await _repository.updateLocation(transactionId, latitude: position.latitude, longitude: position.longitude)));
    } catch (_) {}
  }

  Future<Position?> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      emit(state.copyWith(error: 'Activa la ubicación para seguir el Delivery.'));
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      emit(state.copyWith(error: 'Necesitamos permiso de ubicación para continuar.'));
      return null;
    }
    return Geolocator.getCurrentPosition();
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _fallbackTimer?.cancel();
    _availabilityTimer?.cancel();
    final transactionId = _transactionId;
    await _disposeRealtime(transactionId);
    return super.close();
  }

  Future<void> _disposeRealtime(String? transactionId) async {
    await _deliverySubscription?.cancel();
    await _connectionSubscription?.cancel();
    if (transactionId != null) {
      try {
        await _realtime?.leaveDelivery(transactionId);
      } catch (_) {}
    }
    await _realtime?.dispose();
  }
}
