import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/news_detail_cubit.dart';
import '../cubit/news_detail_state.dart';
import '../widgets/news_image.dart';

class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.newsDetailTitle(locale))),
      body: BlocBuilder<NewsDetailCubit, NewsDetailState>(
        builder: (context, state) {
          if (state.isLoading && state.news == null) return const AppLoading();
          if (state.failure != null || state.isNotFound) {
            return _ErrorContent(
              message: state.isNotFound ? AppLocalizations.newsNotFound(locale) : AppLocalizations.newsDetailLoadFailed(locale),
              retryLabel: AppLocalizations.newsRetry(locale),
              onRetry: context.read<NewsDetailCubit>().retry,
            );
          }
          final news = state.news;
          if (news == null) {
            return _ErrorContent(
                message: AppLocalizations.newsDetailLoadFailed(locale),
                retryLabel: AppLocalizations.newsRetry(locale),
                onRetry: context.read<NewsDetailCubit>().retry,
              );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NewsImage(url: news.featuredImageUrl, height: 230),
                const SizedBox(height: 20),
                Text(news.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  MaterialLocalizations.of(context).formatMediumDate(news.publishedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (news.categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(AppLocalizations.newsCategories(locale), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: news.categories.map((category) => Chip(label: Text(category.name))).toList(growable: false),
                  ),
                ],
                if (news.summary?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 20),
                  Text(AppLocalizations.newsSummary(locale), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(news.summary!.trim(), style: Theme.of(context).textTheme.bodyLarge),
                ],
                const SizedBox(height: 24),
                Text(AppLocalizations.newsContent(locale), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(news.content, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(retryLabel)),
            ],
          ),
        ),
      );
}