import '../../domain/entities/delivery.dart';

class DeliveryModel extends Delivery {
  const DeliveryModel({required super.id, required super.transactionId, required super.sellerUserId, super.driverUserId, super.pickupLatitude, super.pickupLongitude, required super.destinationLatitude, required super.destinationLongitude, super.driverLatitude, super.driverLongitude, required super.status});

  factory DeliveryModel.fromJson(Map<String, dynamic> json) => DeliveryModel(
        id: json['id'] as String,
        transactionId: json['productTransactionId'] as String,
        sellerUserId: json['sellerUserId'] as String,
        driverUserId: json['driverUserId'] as String?,
        pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble(),
        pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble(),
        destinationLatitude: (json['destinationLatitude'] as num).toDouble(),
        destinationLongitude: (json['destinationLongitude'] as num).toDouble(),
        driverLatitude: (json['driverLatitude'] as num?)?.toDouble(),
        driverLongitude: (json['driverLongitude'] as num?)?.toDouble(),
        status: DeliveryStatus.values[(json['status'] as int?)?.clamp(0, 4) ?? 0],
      );
}

class NearbyDeliveryDriverModel extends NearbyDeliveryDriver {
  const NearbyDeliveryDriverModel({required super.userId, required super.displayName, required super.distanceInKm});

  factory NearbyDeliveryDriverModel.fromJson(Map<String, dynamic> json) => NearbyDeliveryDriverModel(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Conductor',
        distanceInKm: (json['distanceInKm'] as num?)?.toDouble() ?? 0,
      );
}
