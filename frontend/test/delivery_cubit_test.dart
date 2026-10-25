import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/delivery/domain/entities/delivery.dart';
import 'package:motohub/features/delivery/domain/repositories/delivery_realtime_repository.dart';
import 'package:motohub/features/delivery/domain/repositories/delivery_repository.dart';
import 'package:motohub/features/delivery/presentation/cubit/delivery_cubit.dart';

void main() {
  test('updates the buyer delivery state when a live location arrives', () async {
    final realtime = _FakeDeliveryRealtimeRepository();
    final cubit = DeliveryCubit(_FakeDeliveryRepository(), realtime);

    await cubit.load('transaction-1', currentUserId: 'buyer-1');
    realtime.updatesController.add(_delivery(driverLatitude: -12.05, driverLongitude: -77.03));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isRealtimeConnected, isTrue);
    expect(cubit.state.delivery?.driverLatitude, -12.05);
    expect(cubit.state.delivery?.driverLongitude, -77.03);

    await cubit.close();
  });
}

Delivery _delivery({double? driverLatitude, double? driverLongitude}) => Delivery(
      id: 'delivery-1',
      transactionId: 'transaction-1',
      sellerUserId: 'seller-1',
      destinationLatitude: -12.1,
      destinationLongitude: -77.1,
      driverLatitude: driverLatitude,
      driverLongitude: driverLongitude,
      status: DeliveryStatus.inTransit,
    );

class _FakeDeliveryRepository implements DeliveryRepository {
  @override
  Future<Delivery> get(String transactionId) async => _delivery();

  @override
  Future<Delivery> request(String transactionId, {required double latitude, required double longitude, required String driverUserId}) async => _delivery();

  @override
  Future<List<NearbyDeliveryDriver>> getNearbyDrivers(String transactionId) async => const [];

  @override
  Future<List<Delivery>> getAssigned() async => const [];

  @override
  Future<bool> getDriverAvailability() async => false;

  @override
  Future<DeliveryDriverEligibility> getDriverEligibility() async => const DeliveryDriverEligibility(isEligible: false, emailConfirmed: false, hasFullName: false, hasPhoneNumber: false, hasQualifiedMotorcycle: false);

  @override
  Future<bool> updateDriverAvailability({double? latitude, double? longitude, required bool isAvailable}) async => isAvailable;

  @override
  Future<Delivery> updateLocation(String transactionId, {required double latitude, required double longitude}) async => _delivery(driverLatitude: latitude, driverLongitude: longitude);

  @override
  Future<Delivery> complete(String transactionId) async => _delivery();
}

class _FakeDeliveryRealtimeRepository implements DeliveryRealtimeRepository {
  final updatesController = StreamController<Delivery>.broadcast();
  final _connectionStatesController = StreamController<DeliveryRealtimeConnectionState>.broadcast();

  @override
  Stream<Delivery> get updates => updatesController.stream;

  @override
  Stream<DeliveryRealtimeConnectionState> get connectionStates => _connectionStatesController.stream;

  @override
  Future<void> start() async {
    _connectionStatesController.add(DeliveryRealtimeConnectionState.connected);
  }

  @override
  Future<void> joinDelivery(String transactionId) async {}

  @override
  Future<void> leaveDelivery(String transactionId) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await updatesController.close();
    await _connectionStatesController.close();
  }
}