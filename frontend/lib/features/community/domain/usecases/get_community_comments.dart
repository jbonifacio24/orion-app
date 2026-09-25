import '../entities/paged_community_comments.dart';
import '../repositories/community_repository.dart';

class GetCommunityComments {
  const GetCommunityComments(this._repository);

  final CommunityRepository _repository;

  Future<PagedCommunityComments> call({required String postId, int page = 1, int pageSize = 20}) =>
      _repository.getComments(postId: postId, page: page, pageSize: pageSize);
}
