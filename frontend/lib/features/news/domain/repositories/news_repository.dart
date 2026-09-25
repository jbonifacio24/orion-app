import '../entities/news_category.dart';
import '../entities/paged_news.dart';

abstract interface class NewsRepository {
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId});
  Future<List<NewsCategory>> getNewsCategories();
}