import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/paged_theft_reports.dart';
import '../../domain/entities/theft_report.dart';
import '../../domain/repositories/theft_repository.dart';
import '../datasources/theft_data_source.dart';

class TheftRepositoryImpl implements TheftRepository {
  const TheftRepositoryImpl(this._dataSource);
  final TheftDataSource _dataSource;

  @override
  Future<PagedTheftReports> getActiveReports({int page = 1, int pageSize = 20}) => _map(() => _dataSource.getActiveReports(page: page, pageSize: pageSize));

  @override
  Future<TheftReport> getReport(String id) => _map(() => _dataSource.getReport(id));

  @override
  Future<PagedTheftReports> getMyReports({int page = 1, int pageSize = 20}) => _map(() => _dataSource.getMyReports(page: page, pageSize: pageSize));

  @override
  Future<TheftReport> createReport(CreateTheftReportInput input) => _map(() => _dataSource.createReport(input));

  @override
  Future<TheftReport> updateStatus(String id, TheftReportStatus status) => _map(() => _dataSource.updateStatus(id, status));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}