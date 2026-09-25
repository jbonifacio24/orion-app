import 'post_author.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.isOwner,
  });

  final String id;
  final String postId;
  final PostAuthor author;
  final String content;
  final DateTime createdAt;
  final bool isOwner;
}
