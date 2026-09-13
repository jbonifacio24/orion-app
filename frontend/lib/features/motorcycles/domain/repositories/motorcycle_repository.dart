import '../entities/motorcycle.dart';

abstract interface class MotorcycleRepository {
  Future<List<Motorcycle>> getAll();
  Future<Motorcycle> getById(String id);
  Future<Motorcycle> create({
    required String brand,
    required String model,
    required int year,
    int? displacement,
    String? color,
    String? licensePlate,
    String? vin,
    String? description,
    required bool isPrimary,
  });
  Future<Motorcycle> update({
    required String id,
    required String brand,
    required String model,
    required int year,
    int? displacement,
    String? color,
    String? licensePlate,
    String? vin,
    String? description,
    required bool isPrimary,
  });
  Future<void> delete(String id);
}
