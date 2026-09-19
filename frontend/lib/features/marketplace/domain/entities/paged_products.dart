import 'product.dart';

class PagedProducts {
  const PagedProducts({required this.items, required this.page, required this.pageSize, required this.totalCount, required this.totalPages});

  final List<Product> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
