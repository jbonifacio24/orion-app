import '../entities/paged_workshops.dart';
import '../entities/workshop_detail.dart';
import '../entities/workshop_filters.dart';

abstract interface class WorkshopRepository {
  Future<PagedWorkshops> getWorkshops(WorkshopFilters filters, {int page = 1});
  Future<WorkshopDetail> getWorkshopDetail(String id);
}