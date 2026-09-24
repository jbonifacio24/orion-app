import '../repositories/community_repository.dart';

class DeleteCommunityPost {
  const DeleteCommunityPost(this._repository);

  final CommunityRepository _repository;

  Future<void> call(String postId) => _repository.deletePost(postId);
}
