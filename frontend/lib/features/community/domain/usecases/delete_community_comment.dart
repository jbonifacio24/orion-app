import '../repositories/community_repository.dart';

class DeleteCommunityComment {
  const DeleteCommunityComment(this._repository);

  final CommunityRepository _repository;

  Future<void> call({required String postId, required String commentId}) =>
      _repository.deleteComment(postId: postId, commentId: commentId);
}
