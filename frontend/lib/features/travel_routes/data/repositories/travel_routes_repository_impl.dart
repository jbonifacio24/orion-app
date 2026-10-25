import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/travel_route.dart';
import '../../domain/repositories/travel_routes_repository.dart';
import '../datasources/travel_routes_data_source.dart';

class TravelRoutesRepositoryImpl implements TravelRoutesRepository {
  const TravelRoutesRepositoryImpl(this._dataSource);

  final TravelRoutesDataSource _dataSource;

  @override
  Future<List<TravelRoute>> getPublished() => _map(_dataSource.getPublished);

  @override
  Future<TravelRoute> create(TravelRouteDraft draft) => _map(() => _dataSource.create(draft));

  @override
  Future<String> join(String routeId) => _map(() => _dataSource.join(routeId));

  @override
  Future<void> delete(String routeId) => _map(() => _dataSource.delete(routeId));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}