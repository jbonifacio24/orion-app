using MotoHub.Application.Marketplace;

namespace MotoHub.Application.Community;

public interface ICommunityService
{
    Task<PagedResponse<PostSummaryResponse>> GetFeedAsync(Guid userId, PostListQueryDto query, CancellationToken cancellationToken);
    Task<PostDetailResponse> GetByIdAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
    Task<PostDetailResponse> CreateAsync(Guid userId, CreatePostRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
}