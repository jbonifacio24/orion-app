import '../entities/community_post.dart';
import '../repositories/community_repository.dart';

class CreateCommunityPost {
  const CreateCommunityPost(this._repository);

  final CommunityRepository _repository;

  Future<CommunityPost> call(String content) => _repository.createPost(content);
}
