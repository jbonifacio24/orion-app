import 'package:dio/dio.dart';

import '../../../../core/error/app_failure.dart';
import '../models/news_models.dart';

class NewsRestDataSource {
  const NewsRestDataSource(this._dio);

  final Dio _dio;

  Future<PagedNewsModel> getNewsFeed({required int page, required int pageSize, String? categoryId}) async {
    final queryParameters = <String, dynamic>{'page': page, 'pageSize': pageSize};
    if (categoryId != null) queryParameters['categoryId'] = categoryId;
    final response = await _dio.get<Map<String, dynamic>>('/news', queryParameters: queryParameters);
    return PagedNewsModel.fromJson(response.data!);
  }

  Future<List<NewsCategoryModel>> getNewsCategories() async {
    final response = await _dio.get<List<dynamic>>('/news/categories');
    final rawCategories = response.data;
    if (rawCategories == null) throw const SerializationFailure('La lista de categorías no es válida.');
    return rawCategories.map((item) {
      if (item is! Map<String, dynamic>) throw const SerializationFailure('Una categoría no es válida.');
      return NewsCategoryModel.fromJson(item);
    }).toList(growable: false);
  }

  Future<NewsDetailModel> getNewsDetail(String newsId) async {
    final response = await _dio.get<Map<String, dynamic>>('/news/${Uri.encodeComponent(newsId)}');
    return NewsDetailModel.fromJson(response.data!);
  }

  Future<NewsDetailModel> createNews({required String title, String? summary, required String content, String? featuredImageUrl}) async {
    final response = await _dio.post<Map<String, dynamic>>('/news', data: {
      'title': title,
      'summary': summary,
      'content': content,
      'featuredImageUrl': featuredImageUrl,
    });
    return NewsDetailModel.fromJson(response.data!);
  }
}