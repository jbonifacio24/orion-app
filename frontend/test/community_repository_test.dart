import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/community/data/datasources/community_rest_data_source.dart';
import 'package:motohub/features/community/data/models/community_models.dart';
import 'package:motohub/features/community/data/repositories/community_repository_impl.dart';
import 'package:motohub/features/community/domain/entities/community_like_state.dart';
import 'package:motohub/features/community/domain/entities/paged_community_comments.dart';

void main() {
  test('maps datasource network failure through ErrorMapper', () async {
    final repository = CommunityRepositoryImpl(_FailingDataSource());

    expect(() => repository.getFeed(), throwsA(isA<NetworkFailure>()));
  });

  test('maps create and delete through the REST datasource contract', () async {
    final dataSource = _SuccessfulDataSource();
    final repository = CommunityRepositoryImpl(dataSource);

    final created = await repository.createPost('content');
    await repository.deletePost(created.id);

    expect(created.id, 'post-1');
    expect(dataSource.createdContent, 'content');
    expect(dataSource.deletedPostId, 'post-1');
  });

  test('maps detail, likes and comments through the REST datasource contract', () async {
    final dataSource = _SuccessfulDataSource();
    final repository = CommunityRepositoryImpl(dataSource);

    final post = await repository.getPost('post-1');
    final like = await repository.likePost('post-1');
    final unlike = await repository.unlikePost('post-1');
    final comments = await repository.getComments(postId: 'post-1', page: 2, pageSize: 20);
    final comment = await repository.createComment(postId: 'post-1', content: 'content');
    await repository.deleteComment(postId: 'post-1', commentId: comment.id);

    expect(post.id, 'post-1');
    expect(like, const TypeMatcher<CommunityLikeState>());
    expect(unlike.likedByCurrentUser, isFalse);
    expect(comments, const TypeMatcher<PagedCommunityComments>());
    expect(comment.postId, 'post-1');
    expect(dataSource.createdCommentContent, 'content');
    expect(dataSource.deletedCommentId, 'comment-1');
  });
}

class _FailingDataSource extends CommunityRestDataSource {
  _FailingDataSource() : super(Dio());

  @override
  Future<PagedCommunityPostsModel> getFeed({int page = 1, int pageSize = 20}) => Future.error(
        DioException(requestOptions: RequestOptions(path: '/api/posts'), type: DioExceptionType.connectionError),
      );
}

class _SuccessfulDataSource extends CommunityRestDataSource {
  _SuccessfulDataSource() : super(Dio());

  String? createdContent;
  String? deletedPostId;
  String? createdCommentContent;
  String? deletedCommentId;

  @override
  Future<CommunityPostModel> createPost(String content) async {
    createdContent = content;
    return CommunityPostModel.fromJson(_postJson);
  }

  @override
  Future<void> deletePost(String postId) async => deletedPostId = postId;

  @override
  Future<CommunityPostModel> getPost(String postId) async => CommunityPostModel.fromJson(_postJson);

  @override
  Future<CommunityLikeStateModel> likePost(String postId) async => CommunityLikeStateModel.fromJson({'likedByCurrentUser': true, 'likeCount': 1});

  @override
  Future<CommunityLikeStateModel> unlikePost(String postId) async => CommunityLikeStateModel.fromJson({'likedByCurrentUser': false, 'likeCount': 0});

  @override
  Future<PagedCommunityCommentsModel> getComments({required String postId, int page = 1, int pageSize = 20}) async => PagedCommunityCommentsModel.fromJson(_commentsJson);

  @override
  Future<CommunityCommentModel> createComment({required String postId, required String content}) async {
    createdCommentContent = content;
    return CommunityCommentModel.fromJson(_commentJson);
  }

  @override
  Future<void> deleteComment({required String postId, required String commentId}) async => deletedCommentId = commentId;
}

final _postJson = <String, dynamic>{
  'id': 'post-1',
  'author': {'userId': 'user-1', 'displayName': 'Rider', 'profileImageUrl': null},
  'content': 'content',
  'publishedAt': '2026-09-24T12:00:00Z',
  'likeCount': 0,
  'commentCount': 0,
  'likedByCurrentUser': false,
  'isOwner': true,
};

final _commentJson = <String, dynamic>{
  'id': 'comment-1',
  'postId': 'post-1',
  'author': {'userId': 'user-1', 'displayName': 'Rider', 'profileImageUrl': null},
  'content': 'content',
  'createdAt': '2026-09-24T12:00:00Z',
  'updatedAt': '2026-09-24T12:00:00Z',
  'isOwner': true,
};

final _commentsJson = <String, dynamic>{
  'items': [_commentJson],
  'page': 2,
  'pageSize': 20,
  'totalCount': 1,
  'totalPages': 2,
};
