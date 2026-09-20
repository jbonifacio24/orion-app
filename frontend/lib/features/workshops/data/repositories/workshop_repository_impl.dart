import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/paged_workshops.dart';
import '../../domain/entities/workshop_detail.dart';
import '../../domain/entities/workshop_filters.dart';
import '../../domain/repositories/workshop_repository.dart';
import '../datasources/workshop_data_source.dart';

class WorkshopRepositoryImpl implements WorkshopRepository {
  const WorkshopRepositoryImpl(this._dataSource);
  final WorkshopDataSource _dataSource;

  @override
  Future<PagedWorkshops> getWorkshops(WorkshopFilters filters, {int page = 1}) => _map(() => _dataSource.getWorkshops(filters, page: page));

  @override
  Future<WorkshopDetail> getWorkshopDetail(String id) => _map(() => _dataSource.getWorkshopDetail(id));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}