import 'package:dio/dio.dart';

import '../../../../core/error/app_failure.dart';
import '../models/news_models.dart';

class NewsRestDataSource {
  const NewsRestDataSource(this._dio);

  final Dio _dio;

  Future<PagedNewsModel> getNewsFeed({required int page, required int pageSize, String? categoryId}) async {
    final queryParameters = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (categoryId != null) queryParameters['categoryId'] = categoryId;
    final response = await _dio.get<Map<String, dynamic>>('/api/news', queryParameters: queryParameters);
    return PagedNewsModel.fromJson(response.data!);
  }

  Future<List<NewsCategoryModel>> getNewsCategories() async {
    final response = await _dio.get<List<dynamic>>('/api/news/categories');
    final rawCategories = response.data;
    if (rawCategories == null) throw const SerializationFailure('La lista de categorías no es válida.');
    return rawCategories.map((item) {
      if (item is! Map<String, dynamic>) throw const SerializationFailure('Una categoría no es válida.');
      return NewsCategoryModel.fromJson(item);
    }).toList(growable: false);
  }
}