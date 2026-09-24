import '../entities/paged_theft_reports.dart';
import '../entities/theft_report.dart';
import '../repositories/theft_repository.dart';

class GetActiveTheftReports {
  const GetActiveTheftReports(this._repository);
  final TheftRepository _repository;
  Future<PagedTheftReports> call({int page = 1, int pageSize = 20}) => _repository.getActiveReports(page: page, pageSize: pageSize);
}

class GetTheftReportDetail {
  const GetTheftReportDetail(this._repository);
  final TheftRepository _repository;
  Future<TheftReport> call(String id) => _repository.getReport(id);
}

class GetMyTheftReports {
  const GetMyTheftReports(this._repository);
  final TheftRepository _repository;
  Future<PagedTheftReports> call({int page = 1, int pageSize = 20}) => _repository.getMyReports(page: page, pageSize: pageSize);
}

class CreateTheftReport {
  const CreateTheftReport(this._repository);
  final TheftRepository _repository;
  Future<TheftReport> call(CreateTheftReportInput input) => _repository.createReport(input);
}

class UpdateTheftReportStatus {
  const UpdateTheftReportStatus(this._repository);
  final TheftRepository _repository;
  Future<TheftReport> call(String id, TheftReportStatus status) => _repository.updateStatus(id, status);
}