import 'community_post.dart';

class PagedCommunityPosts {
  const PagedCommunityPosts({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<CommunityPost> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
