import 'theft_report.dart';

class PagedTheftReports {
  const PagedTheftReports({required this.items, required this.page, required this.pageSize, required this.totalCount, required this.totalPages});

  final List<TheftReport> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}