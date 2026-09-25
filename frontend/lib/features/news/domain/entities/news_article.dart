import 'package:equatable/equatable.dart';

import 'news_category.dart';

class NewsArticle extends Equatable {
  const NewsArticle({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.featuredImageUrl,
    required this.categories,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String? summary;
  final String? featuredImageUrl;
  final List<NewsCategory> categories;
  final DateTime publishedAt;

  @override
  List<Object?> get props => [id, slug, title, summary, featuredImageUrl, categories, publishedAt];
}