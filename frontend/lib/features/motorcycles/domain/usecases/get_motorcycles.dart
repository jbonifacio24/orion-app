import '../entities/motorcycle.dart';
import '../repositories/motorcycle_repository.dart';

class GetMotorcycles {
  const GetMotorcycles(this._repository);
  final MotorcycleRepository _repository;
  Future<List<Motorcycle>> call() => _repository.getAll();
}
