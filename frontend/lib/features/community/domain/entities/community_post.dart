import 'post_author.dart';

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.author,
    required this.content,
    required this.publishedAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByCurrentUser,
    required this.isOwner,
  });

  final String id;
  final PostAuthor author;
  final String content;
  final DateTime? publishedAt;
  final int likeCount;
  final int commentCount;
  final bool likedByCurrentUser;
  final bool isOwner;
}
