import '../entities/news_detail.dart';
import '../repositories/news_repository.dart';

class CreateNews {
  const CreateNews(this._repository);

  final NewsRepository _repository;

  Future<NewsDetail> call({
    required String title,
    String? summary,
    required String content,
    String? featuredImageUrl,
  }) =>
      _repository.createNews(
        title: title,
        summary: summary,
        content: content,
        featuredImageUrl: featuredImageUrl,
      );
}
