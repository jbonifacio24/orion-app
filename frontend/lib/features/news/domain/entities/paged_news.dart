import 'package:equatable/equatable.dart';

import 'news_article.dart';

class PagedNews extends Equatable {
  const PagedNews({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<NewsArticle> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  @override
  List<Object?> get props => [items, page, pageSize, totalCount, totalPages];
}