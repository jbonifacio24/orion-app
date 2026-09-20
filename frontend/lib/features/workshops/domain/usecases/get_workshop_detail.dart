import '../entities/workshop_detail.dart';
import '../repositories/workshop_repository.dart';

class GetWorkshopDetail {
  const GetWorkshopDetail(this._repository);
  final WorkshopRepository _repository;

  Future<WorkshopDetail> call(String id) => _repository.getWorkshopDetail(id);
}