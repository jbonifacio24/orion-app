import '../entities/community_like_state.dart';
import '../repositories/community_repository.dart';

class UnlikeCommunityPost {
  const UnlikeCommunityPost(this._repository);

  final CommunityRepository _repository;

  Future<CommunityLikeState> call(String postId) => _repository.unlikePost(postId);
}
