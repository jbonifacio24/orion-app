import '../repositories/workshop_repository.dart';

class DeleteWorkshop {
  const DeleteWorkshop(this._repository);
  final WorkshopRepository _repository;

  Future<void> call(String id) => _repository.deleteWorkshop(id);
}