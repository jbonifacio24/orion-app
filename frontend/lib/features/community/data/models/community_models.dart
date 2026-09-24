import '../../../../core/error/app_failure.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/entities/paged_community_posts.dart';
import '../../domain/entities/post_author.dart';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
  }
  throw SerializationFailure('La fecha $key no es válida.');
}

class PostAuthorModel extends PostAuthor {
  const PostAuthorModel({required super.userId, required super.displayName, super.profileImageUrl});

  factory PostAuthorModel.fromJson(Map<String, dynamic> json) => PostAuthorModel(
        userId: _requiredString(json, 'userId'),
        displayName: _requiredString(json, 'displayName'),
        profileImageUrl: json['profileImageUrl'] as String?,
      );
}

class CommunityPostModel extends CommunityPost {
  const CommunityPostModel({
    required super.id,
    required super.author,
    required super.content,
    required super.publishedAt,
    required super.likeCount,
    required super.commentCount,
    required super.likedByCurrentUser,
    required super.isOwner,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    if (author is! Map<String, dynamic>) {
      throw const SerializationFailure('El autor de la publicación no es válido.');
    }
    final content = json['content'];
    if (content is! String) throw const SerializationFailure('El contenido de la publicación no es válido.');

    return CommunityPostModel(
      id: _requiredString(json, 'id'),
      author: PostAuthorModel.fromJson(author),
      content: content,
      publishedAt: _optionalDate(json, 'publishedAt'),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      likedByCurrentUser: json['likedByCurrentUser'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }
}

class PagedCommunityPostsModel extends PagedCommunityPosts {
  const PagedCommunityPostsModel({
    required super.items,
    required super.page,
    required super.pageSize,
    required super.totalCount,
    required super.totalPages,
  });

  factory PagedCommunityPostsModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const SerializationFailure('La lista de publicaciones no es válida.');
    }
    return PagedCommunityPostsModel(
      items: rawItems.map((item) {
        if (item is! Map<String, dynamic>) throw const SerializationFailure('Una publicación no es válida.');
        return CommunityPostModel.fromJson(item);
      }).toList(growable: false),
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
