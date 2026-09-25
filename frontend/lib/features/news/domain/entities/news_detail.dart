import 'package:equatable/equatable.dart';

import 'news_category.dart';

class NewsDetail extends Equatable {
  const NewsDetail({
    required this.id,
    required this.slug,
    required this.title,
    required this.summary,
    required this.content,
    required this.featuredImageUrl,
    required this.categories,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String title;
  final String? summary;
  final String content;
  final String? featuredImageUrl;
  final List<NewsCategory> categories;
  final DateTime publishedAt;

  @override
  List<Object?> get props => [id, slug, title, summary, content, featuredImageUrl, categories, publishedAt];
}