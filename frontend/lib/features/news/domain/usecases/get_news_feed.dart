import '../entities/paged_news.dart';
import '../repositories/news_repository.dart';

class GetNewsFeed {
  const GetNewsFeed(this._repository);

  final NewsRepository _repository;

  Future<PagedNews> call({required int page, required int pageSize, String? categoryId}) =>
      _repository.getNewsFeed(page: page, pageSize: pageSize, categoryId: categoryId);
}