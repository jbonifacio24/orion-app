import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/chat_entities.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, required this.isMine, super.key});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine && message.senderProfileImageUrl != null)
              CircleAvatar(radius: 12, backgroundImage: NetworkImage(MediaUrlResolver.resolve(message.senderProfileImageUrl!))),
            if (message.attachments.isEmpty) Text(message.content),
            ...message.attachments.map((attachment) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(MediaUrlResolver.resolve(attachment.url))),
                    icon: Icon(attachment.contentType.startsWith('image/') ? Icons.image : Icons.graphic_eq),
                    label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
                  ),
                )),
            const SizedBox(height: 3),
            Text(
              _time(message.sentAt),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
