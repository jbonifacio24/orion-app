import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/community/data/datasources/community_rest_data_source.dart';
import 'package:motohub/features/community/data/models/community_models.dart';
import 'package:motohub/features/community/data/repositories/community_repository_impl.dart';

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

  @override
  Future<CommunityPostModel> createPost(String content) async {
    createdContent = content;
    return CommunityPostModel.fromJson(_postJson);
  }

  @override
  Future<void> deletePost(String postId) async => deletedPostId = postId;
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
