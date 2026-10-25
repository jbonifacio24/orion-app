import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/chat_entities.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({required this.conversation, required this.onTap, this.selected = false, super.key});

  final Conversation conversation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final participant = conversation.participant;
    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: participant.profileImageUrl == null ? null : NetworkImage(MediaUrlResolver.resolve(participant.profileImageUrl!)),
        child: participant.profileImageUrl == null ? Text(participant.displayName.isEmpty ? '?' : participant.displayName[0].toUpperCase()) : null,
      ),
      title: Text(participant.displayName.isEmpty ? AppLocalizations.defaultUser : participant.displayName),
      subtitle: conversation.lastMessage == null ? null : Text(conversation.lastMessage!.content, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: conversation.unreadCount == 0
          ? null
          : Badge(label: Text('${conversation.unreadCount}')),
    );
  }
}
