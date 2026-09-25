import '../entities/news_category.dart';
import '../repositories/news_repository.dart';

class GetNewsCategories {
  const GetNewsCategories(this._repository);

  final NewsRepository _repository;

  Future<List<NewsCategory>> call() => _repository.getNewsCategories();
}