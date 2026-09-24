import '../entities/community_post.dart';
import '../entities/paged_community_posts.dart';

abstract interface class CommunityRepository {
  Future<PagedCommunityPosts> getFeed({int page = 1, int pageSize = 20});
  Future<CommunityPost> createPost(String content);
  Future<void> deletePost(String postId);
}
