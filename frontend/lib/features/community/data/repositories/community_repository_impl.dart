import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/community_post.dart';
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
  Future<CommunityPost> createPost(String content) => _map(() => _dataSource.createPost(content));

  @override
  Future<void> deletePost(String postId) => _map(() => _dataSource.deletePost(postId));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
