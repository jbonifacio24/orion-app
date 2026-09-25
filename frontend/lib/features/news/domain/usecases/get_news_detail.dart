import '../entities/news_detail.dart';
import '../repositories/news_repository.dart';

class GetNewsDetail {
  const GetNewsDetail(this._repository);

  final NewsRepository _repository;

  Future<NewsDetail> call(String newsId) => _repository.getNewsDetail(newsId);
}