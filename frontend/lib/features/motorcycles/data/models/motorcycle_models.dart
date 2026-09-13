import '../../domain/entities/motorcycle.dart';
import '../../domain/entities/motorcycle_image.dart';

class MotorcycleImageModel extends MotorcycleImage {
  const MotorcycleImageModel({required super.id, required super.url, required super.displayOrder, required super.isPrimary, super.thumbnailUrl});

  factory MotorcycleImageModel.fromJson(Map<String, dynamic> json) => MotorcycleImageModel(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        displayOrder: json['displayOrder'] as int? ?? 0,
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
}

class MotorcycleModel extends Motorcycle {
  const MotorcycleModel({required super.id, required super.brand, required super.model, required super.year, required super.isPrimary, super.displacement, super.color, super.licensePlate, super.vin, super.description, super.images});

  factory MotorcycleModel.fromJson(Map<String, dynamic> json) => MotorcycleModel(
        id: json['id'] as String,
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String? ?? '',
        year: json['year'] as int,
        displacement: json['displacement'] as int?,
        color: json['color'] as String?,
        licensePlate: json['licensePlate'] as String?,
        vin: json['vin'] as String?,
        description: json['description'] as String?,
        isPrimary: json['isPrimary'] as bool? ?? false,
        images: (json['images'] as List<dynamic>? ?? const [])
            .map((item) => MotorcycleImageModel.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class MotorcycleRequestModel {
  const MotorcycleRequestModel({required this.brand, required this.model, required this.year, this.displacement, this.color, this.licensePlate, this.vin, this.description, required this.isPrimary});

  final String brand;
  final String model;
  final int year;
  final int? displacement;
  final String? color;
  final String? licensePlate;
  final String? vin;
  final String? description;
  final bool isPrimary;

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        'year': year,
        'displacement': displacement,
        'color': color,
        'licensePlate': licensePlate,
        'vin': vin,
        'description': description,
        'isPrimary': isPrimary,
      };
}
