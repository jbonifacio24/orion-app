import '../entities/delivery.dart';

abstract interface class DeliveryRepository {
  Future<Delivery> get(String transactionId);
  Future<Delivery> request(String transactionId, {required double latitude, required double longitude, required String driverUserId});
  Future<List<NearbyDeliveryDriver>> getNearbyDrivers(String transactionId);
  Future<List<Delivery>> getAssigned();
  Future<bool> getDriverAvailability();
  Future<DeliveryDriverEligibility> getDriverEligibility();
  Future<bool> updateDriverAvailability({double? latitude, double? longitude, required bool isAvailable});
  Future<Delivery> updateLocation(String transactionId, {required double latitude, required double longitude});
  Future<Delivery> complete(String transactionId);
}
