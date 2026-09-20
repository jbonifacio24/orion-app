import 'workshop.dart';

class PagedWorkshops {
  const PagedWorkshops({required this.items, required this.page, required this.pageSize, required this.totalCount, required this.totalPages});

  final List<Workshop> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}