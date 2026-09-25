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

  CommunityPost copyWith({
    String? id,
    PostAuthor? author,
    String? content,
    DateTime? publishedAt,
    int? likeCount,
    int? commentCount,
    bool? likedByCurrentUser,
    bool? isOwner,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      publishedAt: publishedAt ?? this.publishedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByCurrentUser: likedByCurrentUser ?? this.likedByCurrentUser,
      isOwner: isOwner ?? this.isOwner,
    );
  }
}
