import '../entities/motorcycle.dart';
import '../repositories/motorcycle_repository.dart';

class UpdateMotorcycle {
  const UpdateMotorcycle(this._repository);
  final MotorcycleRepository _repository;
  Future<Motorcycle> call({required String id, required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) => _repository.update(id: id, brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);
}
