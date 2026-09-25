import '../entities/community_post.dart';
import '../repositories/community_repository.dart';

class GetCommunityPost {
  const GetCommunityPost(this._repository);

  final CommunityRepository _repository;

  Future<CommunityPost> call(String postId) => _repository.getPost(postId);
}
