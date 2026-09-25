import 'package:flutter/material.dart';

import '../../domain/entities/news_article.dart';
import 'news_image.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({required this.article, this.onTap, super.key});

  final NewsArticle article;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.featuredImageUrl?.trim();
    final summary = article.summary?.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty) NewsImage(url: imageUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title, style: Theme.of(context).textTheme.titleLarge),
                  if (summary != null && summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(summary, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  if (article.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: article.categories.map((category) => Chip(label: Text(category.name))).toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    MaterialLocalizations.of(context).formatMediumDate(article.publishedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
