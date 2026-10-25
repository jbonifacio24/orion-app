import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/delivery_data_source.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  const DeliveryRepositoryImpl(this._dataSource);
  final DeliveryDataSource _dataSource;

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<Delivery> get(String transactionId) => _map(() => _dataSource.get(transactionId));

  @override
  Future<Delivery> request(String transactionId, {required double latitude, required double longitude, required String driverUserId}) => _map(() => _dataSource.request(transactionId, latitude: latitude, longitude: longitude, driverUserId: driverUserId));

  @override
  Future<List<NearbyDeliveryDriver>> getNearbyDrivers(String transactionId) => _map(() => _dataSource.getNearbyDrivers(transactionId));

  @override
  Future<List<Delivery>> getAssigned() => _map(_dataSource.getAssigned);

  @override
  Future<bool> getDriverAvailability() => _map(_dataSource.getDriverAvailability);

  @override
  Future<DeliveryDriverEligibility> getDriverEligibility() => _map(_dataSource.getDriverEligibility);

  @override
  Future<bool> updateDriverAvailability({double? latitude, double? longitude, required bool isAvailable}) => _map(() => _dataSource.updateDriverAvailability(latitude: latitude, longitude: longitude, isAvailable: isAvailable));

  @override
  Future<Delivery> updateLocation(String transactionId, {required double latitude, required double longitude}) => _map(() => _dataSource.updateLocation(transactionId, latitude: latitude, longitude: longitude));

  @override
  Future<Delivery> complete(String transactionId) => _map(() => _dataSource.complete(transactionId));
}
