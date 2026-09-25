import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/community_comment.dart';
import '../cubit/post_detail_cubit.dart';
import '../cubit/post_detail_state.dart';
import '../widgets/community_comment_tile.dart';
import '../widgets/community_post_card.dart';

class CommunityPostDetailPage extends StatefulWidget {
  const CommunityPostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  State<CommunityPostDetailPage> createState() => _CommunityPostDetailPageState();
}

class _CommunityPostDetailPageState extends State<CommunityPostDetailPage> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PostDetailCubit>().load(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final locale = Localizations.localeOf(context);
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      _showMessage(AppLocalizations.communityCommentRequired(locale));
      return;
    }
    if (content.length > PostDetailCubit.maxCommentLength) {
      _showMessage(AppLocalizations.communityCommentTooLong(locale));
      return;
    }
    final comment = await context.read<PostDetailCubit>().createComment(_commentController.text);
    if (mounted && comment != null) _commentController.clear();
  }

  Future<void> _confirmDelete(CommunityComment comment) async {
    final locale = Localizations.localeOf(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.communityDeleteComment(locale)),
            content: Text(AppLocalizations.communityDeleteCommentConfirmation(locale)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.communityCancel(locale))),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(AppLocalizations.communityDeleteAction(locale))),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) await context.read<PostDetailCubit>().deleteComment(comment);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return BlocListener<PostDetailCubit, PostDetailState>(
      listenWhen: (previous, current) => previous.operationFailure != current.operationFailure,
      listener: (context, state) {
        final message = state.operationFailure;
        if (message != null && message.isNotEmpty) _showMessage(message);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.communityDetail(locale))),
        body: BlocBuilder<PostDetailCubit, PostDetailState>(
          builder: (context, state) => _buildBody(context, state, locale),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostDetailState state, Locale locale) {
    if (state.isPostLoading && state.post == null) return const AppLoading();
    if (state.post == null && state.postFailure != null) {
      return _DetailError(message: state.postFailure!, retryLabel: AppLocalizations.communityRetry(locale), onRetry: context.read<PostDetailCubit>().retryPost);
    }
    final post = state.post;
    if (post == null) return Center(child: Text(AppLocalizations.communityUnavailable(locale)));

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: context.read<PostDetailCubit>().refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
                  context.read<PostDetailCubit>().loadMoreComments();
                }
                return false;
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (state.postFailure != null) _DetailError(message: state.postFailure!, retryLabel: AppLocalizations.communityRetry(locale), onRetry: context.read<PostDetailCubit>().retryPost),
                  CommunityPostCard(
                    post: post,
                    onLike: state.isLikeProcessing ? null : context.read<PostDetailCubit>().toggleLike,
                    isLikeProcessing: state.isLikeProcessing,
                  ),
                  const SizedBox(height: 20),
                  Text(AppLocalizations.communityCommentsTitle(locale), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ..._commentContent(context, state, locale),
                ],
              ),
            ),
          ),
        ),
        _CommentComposer(controller: _commentController, isSubmitting: state.isCommentSubmitting, onSend: _sendComment),
      ],
    );
  }

  List<Widget> _commentContent(BuildContext context, PostDetailState state, Locale locale) {
    if (state.isCommentsLoading && state.comments.isEmpty) return [const AppLoading(compact: true)];
    if (state.commentsFailure != null && state.comments.isEmpty) {
      return [
        _DetailError(message: state.commentsFailure!, retryLabel: AppLocalizations.communityRetry(locale), onRetry: context.read<PostDetailCubit>().retryComments),
      ];
    }
    if (state.comments.isEmpty) return [Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(AppLocalizations.communityNoComments(locale), textAlign: TextAlign.center))];

    return [
      for (final comment in state.comments)
        CommunityCommentTile(
          comment: comment,
          isDeleting: state.deletingCommentId == comment.id,
          onDelete: state.deletingCommentId == null && comment.isOwner ? () => _confirmDelete(comment) : null,
        ),
      if (state.commentsFailure != null)
        _DetailError(message: state.commentsFailure!, retryLabel: AppLocalizations.communityRetry(locale), onRetry: context.read<PostDetailCubit>().retryComments)
      else if (state.isLoadingMoreComments)
        const Padding(padding: EdgeInsets.all(12), child: AppLoading(compact: true)),
    ];
  }
}

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({required this.controller, required this.isSubmitting, required this.onSend});

  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                enabled: !widget.isSubmitting,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppLocalizations.communityCommentHint(locale),
                  counterText: '${widget.controller.text.length} / ${PostDetailCubit.maxCommentLength}',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: AppLocalizations.communitySendComment(locale),
              onPressed: widget.isSubmitting ? null : widget.onSend,
              icon: widget.isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.retryLabel, required this.onRetry});

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(retryLabel)),
          ],
        ),
      );
}
