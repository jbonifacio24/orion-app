import '../entities/community_like_state.dart';
import '../repositories/community_repository.dart';

class LikeCommunityPost {
  const LikeCommunityPost(this._repository);

  final CommunityRepository _repository;

  Future<CommunityLikeState> call(String postId) => _repository.likePost(postId);
}
