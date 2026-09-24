using MotoHub.Domain;

namespace MotoHub.Application.Community;

public sealed record PostListQueryDto(
    int Page = 1,
    int PageSize = 20);

public sealed record CreatePostRequest(string? Content);

public sealed record CreatePostCommentRequest(string? Content);

public sealed record PostAuthorResponse(
    Guid UserId,
    string DisplayName,
    string? ProfileImageUrl);

public sealed record PostSummaryResponse(
    Guid Id,
    PostAuthorResponse Author,
    string Content,
    DateTimeOffset? PublishedAt,
    int LikeCount,
    int CommentCount,
    bool LikedByCurrentUser,
    bool IsOwner);

public sealed record PostDetailResponse(
    Guid Id,
    PostAuthorResponse Author,
    string Content,
    DateTimeOffset? PublishedAt,
    int LikeCount,
    int CommentCount,
    bool LikedByCurrentUser,
    bool IsOwner,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    PostStatus Status);

public sealed record PostLikeStateResponse(
    bool LikedByCurrentUser,
    int LikeCount);

public sealed record PostCommentResponse(
    Guid Id,
    Guid PostId,
    PostAuthorResponse Author,
    string Content,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    bool IsOwner);