using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Community;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Community;

public sealed class CommunityService(MotoHubDbContext dbContext) : ICommunityService
{
    private const int MaxPageSize = 50;
    private const int MaxContentLength = 5000;

    public async Task<PagedResponse<PostSummaryResponse>> GetFeedAsync(
        Guid userId,
        PostListQueryDto query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var posts = PublishedPosts();
        var totalCount = await posts.CountAsync(cancellationToken);
        var rows = await Project(posts, userId)
            .OrderByDescending(x => x.PublishedAt ?? x.CreatedAt)
            .ThenByDescending(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);

        var items = rows.Select(ToSummary).ToArray();
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<PostSummaryResponse>(items, query.Page, query.PageSize, totalCount, totalPages);
    }

    public async Task<PostDetailResponse> GetByIdAsync(Guid userId, Guid postId, CancellationToken cancellationToken)
    {
        var row = await Project(PublishedPosts().Where(x => x.Id == postId), userId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La publicación no existe.");

        return ToDetail(row);
    }

    public async Task<PostDetailResponse> CreateAsync(Guid userId, CreatePostRequest request, CancellationToken cancellationToken)
    {
        var content = NormalizeContent(request.Content);
        var post = new Post
        {
            AuthorUserId = userId,
            Title = null,
            Content = content,
            Status = PostStatus.Published,
            PublishedAt = DateTimeOffset.UtcNow
        };

        dbContext.Posts.Add(post);
        await dbContext.SaveChangesAsync(cancellationToken);
        return await GetByIdAsync(userId, post.Id, cancellationToken);
    }

    public async Task DeleteAsync(Guid userId, Guid postId, CancellationToken cancellationToken)
    {
        var post = await dbContext.Posts
            .Where(x => x.Id == postId && x.AuthorUserId == userId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("La publicación no existe.");

        post.IsDeleted = true;
        post.DeletedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<Post> PublishedPosts()
        => dbContext.Posts
            .AsNoTracking()
            .Where(x => x.Status == PostStatus.Published);

    private static IQueryable<PostQueryRow> Project(IQueryable<Post> posts, Guid userId)
        => posts.Select(post => new PostQueryRow
        {
            Id = post.Id,
            AuthorUserId = post.AuthorUserId,
            AuthorFirstName = post.Author.FirstName,
            AuthorLastName = post.Author.LastName,
            AuthorUserName = post.Author.UserName,
            ProfileImageUrl = post.Author.ProfileImageUrl,
            Content = post.Content,
            PublishedAt = post.PublishedAt,
            CreatedAt = post.CreatedAt,
            UpdatedAt = post.UpdatedAt,
            LikeCount = post.Likes.Count,
            CommentCount = post.Comments.Count,
            LikedByCurrentUser = post.Likes.Any(like => like.UserId == userId),
            IsOwner = post.AuthorUserId == userId,
            Status = post.Status
        });

    private static PostSummaryResponse ToSummary(PostQueryRow row)
        => new(
            row.Id,
            ToAuthor(row),
            row.Content,
            row.PublishedAt,
            row.LikeCount,
            row.CommentCount,
            row.LikedByCurrentUser,
            row.IsOwner);

    private static PostDetailResponse ToDetail(PostQueryRow row)
        => new(
            row.Id,
            ToAuthor(row),
            row.Content,
            row.PublishedAt,
            row.LikeCount,
            row.CommentCount,
            row.LikedByCurrentUser,
            row.IsOwner,
            row.CreatedAt,
            row.UpdatedAt,
            row.Status);

    private static PostAuthorResponse ToAuthor(PostQueryRow row)
        => new(row.AuthorUserId, DisplayName(row.AuthorFirstName, row.AuthorLastName, row.AuthorUserName), row.ProfileImageUrl);

    private static string DisplayName(string? firstName, string? lastName, string userName)
    {
        var first = firstName?.Trim() ?? string.Empty;
        var last = lastName?.Trim() ?? string.Empty;
        if (first.Length == 0 && last.Length == 0) return userName;
        if (first.Length == 0) return last;
        if (last.Length == 0) return first;
        return $"{first} {last}";
    }

    private static string NormalizeContent(string? content)
    {
        var normalized = content?.Trim() ?? string.Empty;
        if (normalized.Length == 0) throw new ValidationException("Content es obligatorio.");
        if (normalized.Length > MaxContentLength) throw new ValidationException("Content debe tener como máximo 5000 caracteres.");
        return normalized;
    }

    private static void ValidateQuery(PostListQueryDto query)
    {
        if (query.Page < 1) throw new ValidationException("Page debe ser mayor o igual a 1.");
        if (query.PageSize < 1 || query.PageSize > MaxPageSize) throw new ValidationException("PageSize debe estar entre 1 y 50.");
    }

    private sealed class PostQueryRow
    {
        public Guid Id { get; init; }
        public Guid AuthorUserId { get; init; }
        public string? AuthorFirstName { get; init; }
        public string? AuthorLastName { get; init; }
        public string AuthorUserName { get; init; } = string.Empty;
        public string? ProfileImageUrl { get; init; }
        public string Content { get; init; } = string.Empty;
        public DateTimeOffset? PublishedAt { get; init; }
        public DateTimeOffset CreatedAt { get; init; }
        public DateTimeOffset UpdatedAt { get; init; }
        public int LikeCount { get; init; }
        public int CommentCount { get; init; }
        public bool LikedByCurrentUser { get; init; }
        public bool IsOwner { get; init; }
        public PostStatus Status { get; init; }
    }
}