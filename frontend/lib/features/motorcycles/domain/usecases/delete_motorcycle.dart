import '../repositories/motorcycle_repository.dart';

class DeleteMotorcycle {
  const DeleteMotorcycle(this._repository);
  final MotorcycleRepository _repository;
  Future<void> call(String id) => _repository.delete(id);
}
