enum DeliveryStatus { requested, inTransit, near, delivered, cancelled }

class Delivery {
  const Delivery({required this.id, required this.transactionId, required this.sellerUserId, this.driverUserId, this.pickupLatitude, this.pickupLongitude, required this.destinationLatitude, required this.destinationLongitude, this.driverLatitude, this.driverLongitude, required this.status});

  final String id;
  final String transactionId;
  final String sellerUserId;
  final String? driverUserId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final DeliveryStatus status;
}

class NearbyDeliveryDriver {
  const NearbyDeliveryDriver({required this.userId, required this.displayName, required this.distanceInKm});

  final String userId;
  final String displayName;
  final double distanceInKm;
}

class DeliveryDriverEligibility {
  const DeliveryDriverEligibility({required this.isEligible, required this.emailConfirmed, required this.hasFullName, required this.hasPhoneNumber, required this.hasQualifiedMotorcycle});

  final bool isEligible;
  final bool emailConfirmed;
  final bool hasFullName;
  final bool hasPhoneNumber;
  final bool hasQualifiedMotorcycle;
}
