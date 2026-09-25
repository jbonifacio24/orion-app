import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/news_detail.dart';
import '../../domain/entities/paged_news.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_rest_data_source.dart';

class NewsRepositoryImpl implements NewsRepository {
  const NewsRepositoryImpl(this._dataSource);

  final NewsRestDataSource _dataSource;

  @override
  Future<PagedNews> getNewsFeed({required int page, required int pageSize, String? categoryId}) =>
      _map(() => _dataSource.getNewsFeed(page: page, pageSize: pageSize, categoryId: categoryId));

  @override
  Future<List<NewsCategory>> getNewsCategories() => _map(_dataSource.getNewsCategories);

  @override
  Future<NewsDetail> getNewsDetail(String newsId) => _map(() => _dataSource.getNewsDetail(newsId));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}