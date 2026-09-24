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
    private const int MaxCommentContentLength = 2000;

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

    public async Task<PostLikeStateResponse> LikePostAsync(Guid userId, Guid postId, CancellationToken cancellationToken)
    {
        await EnsureVisiblePostAsync(postId, cancellationToken);
        var existing = await dbContext.PostLikes
            .SingleOrDefaultAsync(x => x.PostId == postId && x.UserId == userId, cancellationToken);
        if (existing is null)
        {
            dbContext.PostLikes.Add(new PostLike { PostId = postId, UserId = userId });
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException)
            {
                if (!await LikeExistsAsync(postId, userId, cancellationToken)) throw;
                foreach (var entry in dbContext.ChangeTracker.Entries<PostLike>().ToArray()) entry.State = EntityState.Detached;
            }
        }

        return await GetLikeStateAsync(postId, userId, cancellationToken);
    }

    public async Task<PostLikeStateResponse> UnlikePostAsync(Guid userId, Guid postId, CancellationToken cancellationToken)
    {
        await EnsureVisiblePostAsync(postId, cancellationToken);
        var existing = await dbContext.PostLikes
            .SingleOrDefaultAsync(x => x.PostId == postId && x.UserId == userId, cancellationToken);
        if (existing is not null)
        {
            dbContext.PostLikes.Remove(existing);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return await GetLikeStateAsync(postId, userId, cancellationToken);
    }

    public async Task<PagedResponse<PostCommentResponse>> GetCommentsAsync(
        Guid userId,
        Guid postId,
        PostListQueryDto query,
        CancellationToken cancellationToken)
    {
        await EnsureVisiblePostAsync(postId, cancellationToken);
        ValidateQuery(query);
        var comments = dbContext.PostComments
            .AsNoTracking()
            .Where(x => x.PostId == postId && x.ParentCommentId == null);
        var totalCount = await comments.CountAsync(cancellationToken);
        var rows = await ProjectComments(comments, userId)
            .OrderBy(x => x.CreatedAt)
            .ThenBy(x => x.Id)
            .Skip((query.Page - 1) * query.PageSize)
            .Take(query.PageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)query.PageSize);
        return new PagedResponse<PostCommentResponse>(rows.Select(ToComment).ToArray(), query.Page, query.PageSize, totalCount, totalPages);
    }

    public async Task<PostCommentResponse> CreateCommentAsync(
        Guid userId,
        Guid postId,
        CreatePostCommentRequest request,
        CancellationToken cancellationToken)
    {
        await EnsureVisiblePostAsync(postId, cancellationToken);
        var comment = new PostComment
        {
            PostId = postId,
            AuthorUserId = userId,
            ParentCommentId = null,
            Content = NormalizeCommentContent(request.Content)
        };
        dbContext.PostComments.Add(comment);
        await dbContext.SaveChangesAsync(cancellationToken);

        var row = await ProjectComments(
                dbContext.PostComments.AsNoTracking().Where(x => x.Id == comment.Id),
                userId)
            .SingleAsync(cancellationToken);
        return ToComment(row);
    }

    public async Task DeleteCommentAsync(Guid userId, Guid postId, Guid commentId, CancellationToken cancellationToken)
    {
        await EnsureVisiblePostAsync(postId, cancellationToken);
        var comment = await dbContext.PostComments
            .Where(x => x.Id == commentId && x.PostId == postId && x.AuthorUserId == userId && x.ParentCommentId == null)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("El comentario no existe.");
        comment.IsDeleted = true;
        comment.DeletedAt = DateTimeOffset.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private IQueryable<Post> PublishedPosts()
        => dbContext.Posts
            .AsNoTracking()
            .Where(x => x.Status == PostStatus.Published);

    private async Task EnsureVisiblePostAsync(Guid postId, CancellationToken cancellationToken)
    {
        if (!await PublishedPosts().AnyAsync(x => x.Id == postId, cancellationToken))
        {
            throw new ResourceNotFoundException("La publicación no existe.");
        }
    }

    private async Task<bool> LikeExistsAsync(Guid postId, Guid userId, CancellationToken cancellationToken)
        => await dbContext.PostLikes.AsNoTracking().AnyAsync(x => x.PostId == postId && x.UserId == userId, cancellationToken);

    private async Task<PostLikeStateResponse> GetLikeStateAsync(Guid postId, Guid userId, CancellationToken cancellationToken)
    {
        var state = await dbContext.PostLikes.AsNoTracking()
            .Where(x => x.PostId == postId)
            .GroupBy(x => x.PostId)
            .Select(group => new PostLikeStateResponse(
                group.Any(x => x.UserId == userId),
                group.Count()))
            .SingleOrDefaultAsync(cancellationToken);
        return state ?? new PostLikeStateResponse(false, 0);
    }

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

    private static IQueryable<PostCommentQueryRow> ProjectComments(IQueryable<PostComment> comments, Guid userId)
        => comments.Select(comment => new PostCommentQueryRow
        {
            Id = comment.Id,
            PostId = comment.PostId,
            AuthorUserId = comment.AuthorUserId,
            AuthorFirstName = comment.Author.FirstName,
            AuthorLastName = comment.Author.LastName,
            AuthorUserName = comment.Author.UserName,
            ProfileImageUrl = comment.Author.ProfileImageUrl,
            Content = comment.Content,
            CreatedAt = comment.CreatedAt,
            UpdatedAt = comment.UpdatedAt,
            IsOwner = comment.AuthorUserId == userId
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

    private static PostCommentResponse ToComment(PostCommentQueryRow row)
        => new(
            row.Id,
            row.PostId,
            new PostAuthorResponse(row.AuthorUserId, DisplayName(row.AuthorFirstName, row.AuthorLastName, row.AuthorUserName), row.ProfileImageUrl),
            row.Content,
            row.CreatedAt,
            row.UpdatedAt,
            row.IsOwner);

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

    private static string NormalizeCommentContent(string? content)
    {
        var normalized = content?.Trim() ?? string.Empty;
        if (normalized.Length == 0) throw new ValidationException("Content es obligatorio.");
        if (normalized.Length > MaxCommentContentLength) throw new ValidationException("Content debe tener como máximo 2000 caracteres.");
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

    private sealed class PostCommentQueryRow
    {
        public Guid Id { get; init; }
        public Guid PostId { get; init; }
        public Guid AuthorUserId { get; init; }
        public string? AuthorFirstName { get; init; }
        public string? AuthorLastName { get; init; }
        public string AuthorUserName { get; init; } = string.Empty;
        public string? ProfileImageUrl { get; init; }
        public string Content { get; init; } = string.Empty;
        public DateTimeOffset CreatedAt { get; init; }
        public DateTimeOffset UpdatedAt { get; init; }
        public bool IsOwner { get; init; }
    }
}