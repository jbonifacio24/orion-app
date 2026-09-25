import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/community_comment.dart';
import 'community_post_card.dart';

class CommunityCommentTile extends StatelessWidget {
  const CommunityCommentTile({required this.comment, this.onDelete, this.isDeleting = false, super.key});

  final CommunityComment comment;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CommunityAuthorAvatar(author: comment.author),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(comment.author.displayName, style: Theme.of(context).textTheme.titleSmall)),
                    if (comment.isOwner && isDeleting)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (comment.isOwner && onDelete != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: AppLocalizations.communityDeleteComment(locale),
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                  ],
                ),
                Text(MaterialLocalizations.of(context).formatMediumDate(comment.createdAt), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(comment.content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
