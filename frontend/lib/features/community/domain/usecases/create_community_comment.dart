import '../entities/community_comment.dart';
import '../repositories/community_repository.dart';

class CreateCommunityComment {
  const CreateCommunityComment(this._repository);

  final CommunityRepository _repository;

  Future<CommunityComment> call({required String postId, required String content}) =>
      _repository.createComment(postId: postId, content: content);
}
