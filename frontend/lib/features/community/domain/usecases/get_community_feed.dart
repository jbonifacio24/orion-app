import '../entities/paged_community_posts.dart';
import '../repositories/community_repository.dart';

class GetCommunityFeed {
  const GetCommunityFeed(this._repository);

  final CommunityRepository _repository;

  Future<PagedCommunityPosts> call({int page = 1, int pageSize = 20}) =>
      _repository.getFeed(page: page, pageSize: pageSize);
}
