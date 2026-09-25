import 'community_comment.dart';

class PagedCommunityComments {
  const PagedCommunityComments({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<CommunityComment> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
}
