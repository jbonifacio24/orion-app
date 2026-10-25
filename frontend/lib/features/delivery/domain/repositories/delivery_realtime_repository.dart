import '../entities/delivery.dart';

enum DeliveryRealtimeConnectionState { disconnected, connecting, connected, reconnecting, failed }

abstract interface class DeliveryRealtimeRepository {
  Stream<Delivery> get updates;
  Stream<DeliveryRealtimeConnectionState> get connectionStates;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
  Future<void> joinDelivery(String transactionId);
  Future<void> leaveDelivery(String transactionId);
}