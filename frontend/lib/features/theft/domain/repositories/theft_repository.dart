import '../entities/theft_report.dart';
import '../entities/paged_theft_reports.dart';

abstract interface class TheftRepository {
  Future<PagedTheftReports> getActiveReports({int page = 1, int pageSize = 20});
  Future<TheftReport> getReport(String id);
  Future<PagedTheftReports> getMyReports({int page = 1, int pageSize = 20});
  Future<TheftReport> createReport(CreateTheftReportInput input);
  Future<TheftReport> updateStatus(String id, TheftReportStatus status);
}