import '../entities/community_post.dart';
import '../entities/community_comment.dart';
import '../entities/community_like_state.dart';
import '../entities/paged_community_comments.dart';
import '../entities/paged_community_posts.dart';

abstract interface class CommunityRepository {
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20});
  Future<CommunityPost> getPost(String postId);
  Future<CommunityPost> createPost(String content);
  Future<void> deletePost(String postId);
  Future<CommunityLikeState> likePost(String postId);
  Future<CommunityLikeState> unlikePost(String postId);
  Future<PagedCommunityComments> getComments({required String postId, int page = 1, int pageSize = 20});
  Future<CommunityComment> createComment({required String postId, required String content});
  Future<void> deleteComment({required String postId, required String commentId});
}
