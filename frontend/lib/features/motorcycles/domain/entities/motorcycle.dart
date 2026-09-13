import 'motorcycle_image.dart';

class Motorcycle {
  const Motorcycle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.isPrimary,
    this.displacement,
    this.color,
    this.licensePlate,
    this.vin,
    this.description,
    this.images = const [],
  });

  final String id;
  final String brand;
  final String model;
  final int year;
  final int? displacement;
  final String? color;
  final String? licensePlate;
  final String? vin;
  final String? description;
  final bool isPrimary;
  final List<MotorcycleImage> images;
}
