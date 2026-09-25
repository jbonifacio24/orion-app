import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/community/data/models/community_models.dart';

void main() {
  test('maps paged community posts, nullable avatar and feed flags', () {
    final page = PagedCommunityPostsModel.fromJson({
      'items': [
        {
          'id': 'post-1',
          'author': {'userId': 'user-1', 'displayName': 'Ana Rider', 'profileImageUrl': null},
          'content': 'Ruta del domingo',
          'publishedAt': '2026-09-24T12:00:00Z',
          'likeCount': 4,
          'commentCount': 2,
          'likedByCurrentUser': true,
          'isOwner': false,
        },
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });

    final post = page.items.single;
    expect(post.id, 'post-1');
    expect(post.author.userId, 'user-1');
    expect(post.author.profileImageUrl, isNull);
    expect(post.likeCount, 4);
    expect(post.commentCount, 2);
    expect(post.likedByCurrentUser, isTrue);
    expect(post.isOwner, isFalse);
    expect(post.publishedAt, DateTime.utc(2026, 9, 24, 12).toLocal());
  });

  test('rejects malformed post author and paged items', () {
    expect(
      () => CommunityPostModel.fromJson({'id': 'post-1', 'author': null, 'content': 'text'}),
      throwsA(isA<Exception>()),
    );
    expect(
      () => PagedCommunityPostsModel.fromJson({'items': null}),
      throwsA(isA<Exception>()),
    );
  });

  test('maps detail like state and flat paged comments', () {
    final like = CommunityLikeStateModel.fromJson({'likedByCurrentUser': true, 'likeCount': 8});
    final page = PagedCommunityCommentsModel.fromJson({
      'items': [
        {
          'id': 'comment-1',
          'postId': 'post-1',
          'author': {'userId': 'user-2', 'displayName': 'Rider Two', 'profileImageUrl': null},
          'content': 'Buen viaje',
          'createdAt': '2026-09-24T12:00:00Z',
          'updatedAt': '2026-09-24T12:00:00Z',
          'isOwner': true,
        },
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });

    expect(like.likedByCurrentUser, isTrue);
    expect(like.likeCount, 8);
    expect(page.items.single.id, 'comment-1');
    expect(page.items.single.postId, 'post-1');
    expect(page.items.single.author.profileImageUrl, isNull);
    expect(page.items.single.createdAt, DateTime.utc(2026, 9, 24, 12).toLocal());
    expect(page.items.single.isOwner, isTrue);
  });

  test('rejects malformed comments', () {
    expect(
      () => CommunityCommentModel.fromJson({'id': 'comment-1', 'postId': 'post-1', 'author': null, 'content': 'text', 'createdAt': '2026-09-24T12:00:00Z'}),
      throwsA(isA<Exception>()),
    );
    expect(
      () => PagedCommunityCommentsModel.fromJson({'items': null}),
      throwsA(isA<Exception>()),
    );
  });
}
