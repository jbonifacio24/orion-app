import '../../../../core/error/app_failure.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/news_detail.dart';
import '../../domain/entities/paged_news.dart';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  throw SerializationFailure('La fecha $key no es válida.');
}

List<NewsCategory> _categories(Map<String, dynamic> json) {
  final value = json['categories'];
  if (value is! List<dynamic>) throw const SerializationFailure('Las categorías no son válidas.');
  return value.map((item) {
    if (item is! Map<String, dynamic>) throw const SerializationFailure('Una categoría no es válida.');
    return NewsCategoryModel.fromJson(item);
  }).toList(growable: false);
}

class NewsCategoryModel extends NewsCategory {
  const NewsCategoryModel({required super.id, required super.name, required super.slug});

  factory NewsCategoryModel.fromJson(Map<String, dynamic> json) => NewsCategoryModel(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        slug: _requiredString(json, 'slug'),
      );
}

class NewsArticleModel extends NewsArticle {
  const NewsArticleModel({
    required super.id,
    required super.slug,
    required super.title,
    required super.summary,
    required super.featuredImageUrl,
    required super.categories,
    required super.publishedAt,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> json) => NewsArticleModel(
        id: _requiredString(json, 'id'),
        slug: _requiredString(json, 'slug'),
        title: _requiredString(json, 'title'),
        summary: _optionalString(json, 'summary'),
        featuredImageUrl: _optionalString(json, 'featuredImageUrl'),
        categories: _categories(json),
        publishedAt: _requiredDate(json, 'publishedAt'),
      );
}

class NewsDetailModel extends NewsDetail {
  const NewsDetailModel({
    required super.id,
    required super.slug,
    required super.title,
    required super.summary,
    required super.content,
    required super.featuredImageUrl,
    required super.categories,
    required super.publishedAt,
  });

  factory NewsDetailModel.fromJson(Map<String, dynamic> json) => NewsDetailModel(
        id: _requiredString(json, 'id'),
        slug: _requiredString(json, 'slug'),
        title: _requiredString(json, 'title'),
        summary: _optionalString(json, 'summary'),
        content: _requiredString(json, 'content'),
        featuredImageUrl: _optionalString(json, 'featuredImageUrl'),
        categories: _categories(json),
        publishedAt: _requiredDate(json, 'publishedAt'),
      );
}

class PagedNewsModel extends PagedNews {
  const PagedNewsModel({
    required super.items,
    required super.page,
    required super.pageSize,
    required super.totalCount,
    required super.totalPages,
  });

  factory PagedNewsModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) throw const SerializationFailure('La lista de noticias no es válida.');
    return PagedNewsModel(
      items: rawItems.map((item) {
        if (item is! Map<String, dynamic>) throw const SerializationFailure('Una noticia no es válida.');
        return NewsArticleModel.fromJson(item);
      }).toList(growable: false),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      totalCount: _requiredInt(json, 'totalCount'),
      totalPages: _requiredInt(json, 'totalPages'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw SerializationFailure('El campo $key no es válido.');
}