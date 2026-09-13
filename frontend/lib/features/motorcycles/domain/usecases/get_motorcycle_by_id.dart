import '../entities/motorcycle.dart';
import '../repositories/motorcycle_repository.dart';

class GetMotorcycleById {
  const GetMotorcycleById(this._repository);
  final MotorcycleRepository _repository;
  Future<Motorcycle> call(String id) => _repository.getById(id);
}
