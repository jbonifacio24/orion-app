import 'package:dio/dio.dart';

import '../../domain/entities/delivery.dart';
import '../models/delivery_model.dart';

class DeliveryDataSource {
  const DeliveryDataSource(this._dio);
  final Dio _dio;

  Future<DeliveryModel> get(String transactionId) async {
    final response = await _dio.get<Map<String, dynamic>>('/transactions/$transactionId/delivery');
    return DeliveryModel.fromJson(response.data!);
  }

  Future<DeliveryModel> request(String transactionId, {required double latitude, required double longitude, required String driverUserId}) async {
    final response = await _dio.post<Map<String, dynamic>>('/transactions/$transactionId/delivery', data: {'destinationLatitude': latitude, 'destinationLongitude': longitude, 'driverUserId': driverUserId});
    return DeliveryModel.fromJson(response.data!);
  }

  Future<List<NearbyDeliveryDriverModel>> getNearbyDrivers(String transactionId) async {
    final response = await _dio.get<List<dynamic>>('/transactions/$transactionId/delivery/drivers');
    return (response.data ?? []).whereType<Map<String, dynamic>>().map(NearbyDeliveryDriverModel.fromJson).toList(growable: false);
  }

  Future<List<DeliveryModel>> getAssigned() async {
    final response = await _dio.get<List<dynamic>>('/delivery/assigned');
    return (response.data ?? []).whereType<Map<String, dynamic>>().map(DeliveryModel.fromJson).toList(growable: false);
  }

  Future<bool> getDriverAvailability() async {
    final response = await _dio.get<Map<String, dynamic>>('/delivery/driver-availability');
    return response.data?['isAvailable'] as bool? ?? false;
  }

  Future<DeliveryDriverEligibility> getDriverEligibility() async {
    final response = await _dio.get<Map<String, dynamic>>('/delivery/driver-eligibility');
    final data = response.data!;
    return DeliveryDriverEligibility(
      isEligible: data['isEligible'] as bool? ?? false,
      emailConfirmed: data['emailConfirmed'] as bool? ?? false,
      hasFullName: data['hasFullName'] as bool? ?? false,
      hasPhoneNumber: data['hasPhoneNumber'] as bool? ?? false,
      hasQualifiedMotorcycle: data['hasQualifiedMotorcycle'] as bool? ?? false,
    );
  }

  Future<bool> updateDriverAvailability({double? latitude, double? longitude, required bool isAvailable}) async {
    final response = await _dio.put<Map<String, dynamic>>('/delivery/driver-availability', data: {'latitude': latitude, 'longitude': longitude, 'isAvailable': isAvailable});
    return response.data?['isAvailable'] as bool? ?? false;
  }

  Future<DeliveryModel> updateLocation(String transactionId, {required double latitude, required double longitude}) async {
    final response = await _dio.put<Map<String, dynamic>>('/transactions/$transactionId/delivery/location', data: {'latitude': latitude, 'longitude': longitude});
    return DeliveryModel.fromJson(response.data!);
  }

  Future<DeliveryModel> complete(String transactionId) async {
    final response = await _dio.post<Map<String, dynamic>>('/transactions/$transactionId/delivery/complete');
    return DeliveryModel.fromJson(response.data!);
  }
}
