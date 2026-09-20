import '../entities/paged_workshops.dart';
import '../entities/workshop_filters.dart';
import '../repositories/workshop_repository.dart';

class GetWorkshops {
  const GetWorkshops(this._repository);
  final WorkshopRepository _repository;

  Future<PagedWorkshops> call(WorkshopFilters filters, {int page = 1}) => _repository.getWorkshops(filters, page: page);
}