import '../repositories/motorcycle_repository.dart';

class DeleteMotorcycleAsAdmin {
  const DeleteMotorcycleAsAdmin(this._repository);
  final MotorcycleRepository _repository;

  Future<void> call(String id) => _repository.deleteAsAdmin(id);
}