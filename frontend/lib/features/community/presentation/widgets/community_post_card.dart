import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/entities/post_author.dart';

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({required this.post, this.onDelete, this.isDeleting = false, super.key});

  final CommunityPost post;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final publishedAt = post.publishedAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(author: post.author),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.displayName, style: Theme.of(context).textTheme.titleMedium),
                      if (publishedAt != null)
                        Text(
                          MaterialLocalizations.of(context).formatMediumDate(publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (post.isOwner && isDeleting)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (post.isOwner && onDelete != null)
                  IconButton(
                    tooltip: AppLocalizations.communityDeleteAction(locale),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(post.content, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  post.likedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: post.likedByCurrentUser ? Theme.of(context).colorScheme.primary : null,
                ),
                const SizedBox(width: 6),
                Text('${post.likeCount} ${AppLocalizations.communityLikes(locale)}'),
                const SizedBox(width: 20),
                const Icon(Icons.mode_comment_outlined, size: 20),
                const SizedBox(width: 6),
                Text('${post.commentCount} ${AppLocalizations.communityComments(locale)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.author});

  final PostAuthor author;

  @override
  Widget build(BuildContext context) {
    final imageUrl = author.profileImageUrl;
    final initials = author.displayName.trim().isEmpty
        ? '?'
      : author.displayName.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 22,
      foregroundImage: imageUrl == null || imageUrl.isEmpty ? null : NetworkImage(imageUrl),
      onForegroundImageError: imageUrl == null || imageUrl.isEmpty ? null : (_, __) {},
      child: Text(initials),
    );
  }
}
