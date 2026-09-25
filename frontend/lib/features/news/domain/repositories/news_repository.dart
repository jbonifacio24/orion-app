import '../entities/news_category.dart';
import '../entities/news_detail.dart';
import '../entities/paged_news.dart';

abstract interface class NewsRepository {
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId});
  Future<List<NewsCategory>> getNewsCategories();
  Future<NewsDetail> getNewsDetail(String newsId);
}