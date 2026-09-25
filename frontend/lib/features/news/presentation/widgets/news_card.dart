import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/news_article.dart';

class NewsCard extends StatelessWidget {
  const NewsCard({required this.article, super.key});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final imageUrl = article.featuredImageUrl?.trim();
    final summary = article.summary?.trim();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) _NewsImage(url: imageUrl),
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
    );
  }
}

class _NewsImage extends StatelessWidget {
  const _NewsImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    String? resolvedUrl;
    try {
      resolvedUrl = MediaUrlResolver.resolve(url);
    } catch (_) {
      resolvedUrl = null;
    }
    if (resolvedUrl == null || resolvedUrl.isEmpty) return _fallback(context);
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: 120,
          width: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported_outlined),
                const SizedBox(height: 4),
                Text(AppLocalizations.newsImageUnavailable(Localizations.localeOf(context))),
              ],
            ),
          ),
        ),
      );
}