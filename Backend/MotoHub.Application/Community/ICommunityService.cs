using MotoHub.Application.Marketplace;

namespace MotoHub.Application.Community;

public interface ICommunityService
{
    Task<PagedResponse<PostSummaryResponse>> GetFeedAsync(Guid userId, PostListQueryDto query, CancellationToken cancellationToken);
    Task<PostDetailResponse> GetByIdAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
    Task<PostDetailResponse> CreateAsync(Guid userId, CreatePostRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
    Task<PostLikeStateResponse> LikePostAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
    Task<PostLikeStateResponse> UnlikePostAsync(Guid userId, Guid postId, CancellationToken cancellationToken);
    Task<PagedResponse<PostCommentResponse>> GetCommentsAsync(Guid userId, Guid postId, PostListQueryDto query, CancellationToken cancellationToken);
    Task<PostCommentResponse> CreateCommentAsync(Guid userId, Guid postId, CreatePostCommentRequest request, CancellationToken cancellationToken);
    Task DeleteCommentAsync(Guid userId, Guid postId, Guid commentId, CancellationToken cancellationToken);
}