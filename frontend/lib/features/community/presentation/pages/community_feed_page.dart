import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/community_post.dart';
import '../cubit/community_feed_cubit.dart';
import '../cubit/community_feed_state.dart';
import '../widgets/community_post_card.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityFeedCubit>().loadInitial();
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      context.read<CommunityFeedCubit>().loadMore();
    }
  }

  Future<void> _openCreate() async {
    final post = await context.push<CommunityPost>(RouteNames.communityCreatePath);
    if (mounted && post != null) context.read<CommunityFeedCubit>().insertCreatedPost(post);
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final locale = Localizations.localeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.communityDelete(locale)),
        content: Text(AppLocalizations.communityDeleteConfirmation(locale)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.communityCancel(locale))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.communityDeleteAction(locale))),
        ],
      ),
    );
    if (confirmed == true && mounted) await context.read<CommunityFeedCubit>().deletePost(post.id);
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
    return BlocListener<CommunityFeedCubit, CommunityFeedState>(
      listenWhen: (previous, current) => previous.operationFailure != current.operationFailure,
      listener: (context, state) {
        final message = state.operationFailure;
        if (message != null && message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.communityTitle(locale)),
          actions: [
            IconButton(
              tooltip: AppLocalizations.communityCreate(locale),
              onPressed: _openCreate,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: BlocBuilder<CommunityFeedCubit, CommunityFeedState>(
          builder: (context, state) => _buildContent(context, state, locale),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CommunityFeedState state, Locale locale) {
    if (state.isInitialLoading && state.items.isEmpty) return const AppLoading();
    if (state.failure != null && state.items.isEmpty) {
      return _ErrorContent(
        message: state.failure!,
        retryLabel: AppLocalizations.retry,
        onRetry: context.read<CommunityFeedCubit>().retry,
      );
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: context.read<CommunityFeedCubit>().refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .32),
            Center(child: Text(AppLocalizations.communityEmpty(locale))),
          ],
        ),
      );
    }

    final hasFooter = state.isLoadingMore || state.loadingMoreFailure != null;
    return RefreshIndicator(
      onRefresh: context.read<CommunityFeedCubit>().refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: state.items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, index) => SizedBox(height: index == state.items.length - 1 ? 12 : 12),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            if (state.loadingMoreFailure != null) {
              return _ErrorContent(
                message: state.loadingMoreFailure!,
                retryLabel: AppLocalizations.retry,
                onRetry: context.read<CommunityFeedCubit>().retryLoadMore,
              );
            }
            return const Padding(padding: EdgeInsets.all(12), child: AppLoading(compact: true));
          }
          final post = state.items[index];
          return CommunityPostCard(
            post: post,
            onDelete: state.deletingPostId == null ? () => _confirmDelete(post) : null,
            isDeleting: state.deletingPostId == post.id,
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
