import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/community_comment.dart';
import '../../domain/entities/community_like_state.dart';
import '../../domain/entities/community_post.dart';
import '../../domain/entities/paged_community_comments.dart';
import '../../domain/entities/paged_community_posts.dart';
import '../../domain/repositories/community_repository.dart';
import '../datasources/community_rest_data_source.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  const CommunityRepositoryImpl(this._dataSource);

  final CommunityRestDataSource _dataSource;

  @override
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20}) =>
      _map(() => _dataSource.getFeed(page: page, pageSize: pageSize));

  @override
  Future<CommunityPost> getPost(String postId) => _map(() => _dataSource.getPost(postId));

  @override
  Future<CommunityPost> createPost(String content) => _map(() => _dataSource.createPost(content));

  @override
  Future<void> deletePost(String postId) => _map(() => _dataSource.deletePost(postId));

    @override
    Future<CommunityLikeState> likePost(String postId) => _map(() => _dataSource.likePost(postId));

    @override
    Future<CommunityLikeState> unlikePost(String postId) => _map(() => _dataSource.unlikePost(postId));

    @override
    Future<PagedCommunityComments> getComments({required String postId, int page = 1, int pageSize = 20}) =>
      _map(() => _dataSource.getComments(postId: postId, page: page, pageSize: pageSize));

    @override
    Future<CommunityComment> createComment({required String postId, required String content}) =>
      _map(() => _dataSource.createComment(postId: postId, content: content));

    @override
    Future<void> deleteComment({required String postId, required String commentId}) =>
      _map(() => _dataSource.deleteComment(postId: postId, commentId: commentId));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
