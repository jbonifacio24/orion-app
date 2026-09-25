import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/news_feed_cubit.dart';
import '../cubit/news_feed_state.dart';
import '../widgets/news_card.dart';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NewsFeedCubit>().loadInitial();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      context.read<NewsFeedCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.newsTitle(locale))),
      body: BlocBuilder<NewsFeedCubit, NewsFeedState>(
        builder: (context, state) => Column(
          children: [
            _CategorySelector(state: state),
            Expanded(child: _buildContent(context, state, locale)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, NewsFeedState state, Locale locale) {
    if (state.isInitialLoading && state.items.isEmpty) return const AppLoading();
    if (state.failure != null && state.items.isEmpty) {
      return _ErrorContent(
        message: state.failure!,
        retryLabel: AppLocalizations.newsRetry(locale),
        onRetry: context.read<NewsFeedCubit>().retry,
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: context.read<NewsFeedCubit>().refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .28),
            Center(child: Text(AppLocalizations.newsEmpty(locale))),
          ],
        ),
      );
    }

    final hasFooter = state.isLoadingMore || state.loadingMoreFailure != null;
    return RefreshIndicator(
      onRefresh: context.read<NewsFeedCubit>().refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: state.items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.loadingMoreFailure != null) {
              return _ErrorContent(
                message: state.loadingMoreFailure!,
                retryLabel: AppLocalizations.newsRetry(locale),
                onRetry: context.read<NewsFeedCubit>().retryLoadMore,
              );
            }
            return const Padding(padding: EdgeInsets.all(12), child: AppLoading(compact: true));
          }
          return NewsCard(article: state.items[index]);
        },
      ),
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.state});

  final NewsFeedState state;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (state.categoriesFailure != null && state.categories.isEmpty) {
      return SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(child: Text(AppLocalizations.newsCategoriesLoadFailed(locale), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: AppLocalizations.newsRetry(locale),
              onPressed: context.read<NewsFeedCubit>().retryCategories,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 62,
      child: state.isCategoriesLoading && state.categories.isEmpty
          ? const AppLoading(compact: true)
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                ChoiceChip(
                  label: Text(AppLocalizations.newsAll(locale)),
                  selected: state.selectedCategoryId == null,
                  onSelected: (_) => context.read<NewsFeedCubit>().selectCategory(null),
                ),
                const SizedBox(width: 8),
                ...state.categories.map((category) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category.name),
                        selected: state.selectedCategoryId == category.id,
                        onSelected: (_) => context.read<NewsFeedCubit>().selectCategory(category.id),
                      ),
                    )),
              ],
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