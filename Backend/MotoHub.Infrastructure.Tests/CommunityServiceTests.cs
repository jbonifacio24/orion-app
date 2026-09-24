using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Community;
using MotoHub.Application.Errors;
using MotoHub.Domain;
using MotoHub.Infrastructure.Community;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class CommunityServiceTests
{
    [Fact]
    public async Task Get_feed_returns_empty_page_when_no_published_posts_exist()
    {
        await using var context = CreateContext();
        var response = await Service(context).GetFeedAsync(Guid.NewGuid(), new(), default);

        Assert.Empty(response.Items);
        Assert.Equal(0, response.TotalCount);
        Assert.Equal(0, response.TotalPages);
    }

    [Fact]
    public async Task Get_feed_returns_projected_counts_author_flags_and_deterministic_paging()
    {
        await using var context = CreateContext();
        var current = AddUser(context, "current", "Ana", "Rider", "/ana.png");
        var other = AddUser(context, "other", "Luis", "Moto");
        var first = AddPost(context, other, "first", DateTimeOffset.UtcNow.AddMinutes(-2));
        var second = AddPost(context, current, "second", DateTimeOffset.UtcNow.AddMinutes(-1));
        var sameTimeA = AddPost(context, other, "same-a", DateTimeOffset.UtcNow);
        var sameTimeB = AddPost(context, other, "same-b", sameTimeA.PublishedAt!.Value);
        context.PostLikes.AddRange(new PostLike { PostId = first.Id, UserId = current.Id }, new PostLike { PostId = first.Id, UserId = other.Id });
        context.PostComments.AddRange(
            new PostComment { PostId = first.Id, AuthorUserId = current.Id, Content = "visible" },
            new PostComment { PostId = first.Id, AuthorUserId = current.Id, Content = "deleted", IsDeleted = true, DeletedAt = DateTimeOffset.UtcNow });
        await context.SaveChangesAsync();

        var response = await Service(context).GetFeedAsync(current.Id, new(PageSize: 4), default);

        Assert.Equal(4, response.Items.Count);
        Assert.Equal(new[] { sameTimeA.Id, sameTimeB.Id }.OrderByDescending(x => x).ToArray(), response.Items.Take(2).Select(x => x.Id).ToArray());
        var firstDto = response.Items.Single(x => x.Id == first.Id);
        Assert.Equal("Luis Moto", firstDto.Author.DisplayName);
        Assert.Equal("/ana.png", response.Items.Single(x => x.Id == second.Id).Author.ProfileImageUrl);
        Assert.Equal(2, firstDto.LikeCount);
        Assert.Equal(1, firstDto.CommentCount);
        Assert.True(firstDto.LikedByCurrentUser);
        Assert.False(firstDto.IsOwner);
        Assert.True(response.Items.Single(x => x.Id == second.Id).IsOwner);
        Assert.Equal(1, response.TotalPages);
        Assert.Equal(4, response.TotalCount);
    }

    [Fact]
    public async Task Get_feed_excludes_non_published_and_soft_deleted_posts()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        AddPost(context, author, "published", DateTimeOffset.UtcNow, PostStatus.Published);
        AddPost(context, author, "draft", DateTimeOffset.UtcNow, PostStatus.Draft);
        AddPost(context, author, "archived", DateTimeOffset.UtcNow, PostStatus.Archived);
        AddPost(context, author, "removed", DateTimeOffset.UtcNow, PostStatus.Removed);
        AddPost(context, author, "deleted", DateTimeOffset.UtcNow, PostStatus.Published, isDeleted: true);
        await context.SaveChangesAsync();

        var response = await Service(context).GetFeedAsync(author.Id, new(), default);

        var item = Assert.Single(response.Items);
        Assert.Equal("published", item.Content);
    }

    [Fact]
    public async Task Create_trims_content_sets_server_fields_and_returns_author_projection()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author", "Ana", null);
        await context.SaveChangesAsync();

        var response = await Service(context).CreateAsync(author.Id, new("  hello MotoHub  "), default);
        var stored = await context.Posts.SingleAsync();

        Assert.Equal("hello MotoHub", stored.Content);
        Assert.Null(stored.Title);
        Assert.Equal(author.Id, stored.AuthorUserId);
        Assert.Equal(PostStatus.Published, stored.Status);
        Assert.NotNull(stored.PublishedAt);
        Assert.Equal("Ana", response.Author.DisplayName);
        Assert.Equal("hello MotoHub", response.Content);
        Assert.True(response.IsOwner);
    }

    [Fact]
    public async Task Create_rejects_empty_whitespace_and_content_over_5000_but_accepts_exact_limit()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(author.Id, new(null), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(author.Id, new("   "), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(author.Id, new(new string('x', 5001)), default));
        var response = await service.CreateAsync(author.Id, new(new string('x', 5000)), default);

        Assert.Equal(5000, response.Content.Length);
    }

    [Fact]
    public async Task Get_feed_validates_page_and_page_size_limits()
    {
        await using var context = CreateContext();
        var service = Service(context);
        var userId = Guid.NewGuid();

        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(userId, new(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(userId, new(PageSize: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(userId, new(PageSize: 51), default));
    }

    [Fact]
    public async Task Get_detail_returns_counts_flags_and_hides_unpublished_or_missing_posts()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner", null, null, "/owner.png");
        var viewer = AddUser(context, "viewer");
        var post = AddPost(context, owner, "detail", DateTimeOffset.UtcNow);
        context.PostLikes.Add(new PostLike { PostId = post.Id, UserId = viewer.Id });
        context.PostComments.Add(new PostComment { PostId = post.Id, AuthorUserId = viewer.Id, Content = "comment" });
        var draft = AddPost(context, owner, "draft", DateTimeOffset.UtcNow, PostStatus.Draft);
        await context.SaveChangesAsync();

        var response = await Service(context).GetByIdAsync(viewer.Id, post.Id, default);

        Assert.Equal("owner", response.Author.DisplayName);
        Assert.Equal("/owner.png", response.Author.ProfileImageUrl);
        Assert.Equal(1, response.LikeCount);
        Assert.Equal(1, response.CommentCount);
        Assert.True(response.LikedByCurrentUser);
        Assert.False(response.IsOwner);
        Assert.Equal(PostStatus.Published, response.Status);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).GetByIdAsync(viewer.Id, draft.Id, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).GetByIdAsync(viewer.Id, Guid.NewGuid(), default));
    }

    [Fact]
    public async Task Delete_only_allows_owner_and_soft_deletes_the_post_without_hard_deleting_it()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var stranger = AddUser(context, "stranger");
        var post = AddPost(context, owner, "owned", DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.DeleteAsync(stranger.Id, post.Id, default));
        await service.DeleteAsync(owner.Id, post.Id, default);

        var stored = await context.Posts.IgnoreQueryFilters().SingleAsync(x => x.Id == post.Id);
        Assert.True(stored.IsDeleted);
        Assert.NotNull(stored.DeletedAt);
        Assert.Empty(await service.GetFeedAsync(owner.Id, new(), default).ContinueWith(task => task.Result.Items));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetByIdAsync(owner.Id, post.Id, default));
    }

    [Fact]
    public async Task Like_is_idempotent_and_returns_persisted_count_and_state()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var current = AddUser(context, "current");
        var post = AddPost(context, author, "post", DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();
        var service = Service(context);

        var first = await service.LikePostAsync(current.Id, post.Id, default);
        var second = await service.LikePostAsync(current.Id, post.Id, default);

        Assert.True(first.LikedByCurrentUser);
        Assert.Equal(1, first.LikeCount);
        Assert.True(second.LikedByCurrentUser);
        Assert.Equal(1, second.LikeCount);
        Assert.Equal(1, await context.PostLikes.CountAsync());
    }

    [Fact]
    public async Task Unlike_is_idempotent_and_hard_deletes_the_like()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var current = AddUser(context, "current");
        var post = AddPost(context, author, "post", DateTimeOffset.UtcNow);
        context.PostLikes.Add(new PostLike { PostId = post.Id, UserId = current.Id });
        await context.SaveChangesAsync();
        var service = Service(context);

        var first = await service.UnlikePostAsync(current.Id, post.Id, default);
        var second = await service.UnlikePostAsync(current.Id, post.Id, default);

        Assert.False(first.LikedByCurrentUser);
        Assert.Equal(0, first.LikeCount);
        Assert.False(second.LikedByCurrentUser);
        Assert.Equal(0, second.LikeCount);
        Assert.Empty(await context.PostLikes.ToListAsync());
    }

    [Fact]
    public async Task Like_and_unlike_reject_non_visible_posts()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var current = AddUser(context, "current");
        var draft = AddPost(context, author, "draft", DateTimeOffset.UtcNow, PostStatus.Draft);
        var deleted = AddPost(context, author, "deleted", DateTimeOffset.UtcNow, isDeleted: true);
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.LikePostAsync(current.Id, draft.Id, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UnlikePostAsync(current.Id, deleted.Id, default));
    }

    [Fact]
    public async Task Get_comments_returns_direct_comments_in_ascending_order_with_paging_and_projection()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner", "Post", "Owner");
        var other = AddUser(context, "other", "Comment", "Author", "/author.png");
        var post = AddPost(context, owner, "post", DateTimeOffset.UtcNow);
        var first = AddComment(context, post, other, "first", DateTimeOffset.UtcNow.AddMinutes(-2));
        var second = AddComment(context, post, owner, "second", DateTimeOffset.UtcNow.AddMinutes(-1));
        var third = AddComment(context, post, other, "third", DateTimeOffset.UtcNow);
        AddComment(context, post, other, "reply", DateTimeOffset.UtcNow, parent: first);
        await context.SaveChangesAsync();
        var baseTime = DateTimeOffset.UtcNow.AddMinutes(-3);
        first.CreatedAt = baseTime;
        second.CreatedAt = baseTime.AddMinutes(1);
        third.CreatedAt = baseTime.AddMinutes(2);
        await context.SaveChangesAsync();

        var response = await Service(context).GetCommentsAsync(owner.Id, post.Id, new(PageSize: 2), default);
        var items = response.Items.ToArray();

        Assert.Equal(3, response.TotalCount);
        Assert.Equal(2, response.TotalPages);
        Assert.Equal(new[] { first.Id, second.Id }, response.Items.Select(x => x.Id).ToArray());
        Assert.Equal("Comment Author", items[0].Author.DisplayName);
        Assert.Equal("/author.png", items[0].Author.ProfileImageUrl);
        Assert.False(items[0].IsOwner);
        Assert.True(items[1].IsOwner);
        Assert.Equal(third.Id, (await Service(context).GetCommentsAsync(owner.Id, post.Id, new(Page: 2, PageSize: 2), default)).Items.Single().Id);
    }

    [Fact]
    public async Task Create_comment_trims_content_sets_server_fields_and_rejects_invalid_lengths()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var post = AddPost(context, author, "post", DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();
        var service = Service(context);

        var response = await service.CreateCommentAsync(author.Id, post.Id, new("  hello  "), default);
        var stored = await context.PostComments.SingleAsync();

        Assert.Equal("hello", stored.Content);
        Assert.Equal(post.Id, stored.PostId);
        Assert.Equal(author.Id, stored.AuthorUserId);
        Assert.Null(stored.ParentCommentId);
        Assert.NotEqual(default, stored.CreatedAt);
        Assert.Equal("hello", response.Content);
        Assert.True(response.IsOwner);
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateCommentAsync(author.Id, post.Id, new(null), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateCommentAsync(author.Id, post.Id, new(new string('x', 2001)), default));
        var exact = await service.CreateCommentAsync(author.Id, post.Id, new(new string('x', 2000)), default);
        Assert.Equal(2000, exact.Content.Length);
    }

    [Fact]
    public async Task Create_comment_rejects_non_visible_post()
    {
        await using var context = CreateContext();
        var author = AddUser(context, "author");
        var post = AddPost(context, author, "draft", DateTimeOffset.UtcNow, PostStatus.Draft);
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).CreateCommentAsync(author.Id, post.Id, new("comment"), default));
    }

    [Fact]
    public async Task Delete_comment_is_owner_only_soft_deletes_and_updates_comment_count()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var stranger = AddUser(context, "stranger");
        var post = AddPost(context, owner, "post", DateTimeOffset.UtcNow);
        var comment = AddComment(context, post, owner, "comment", DateTimeOffset.UtcNow);
        var otherPost = AddPost(context, owner, "other", DateTimeOffset.UtcNow);
        var otherComment = AddComment(context, otherPost, owner, "other comment", DateTimeOffset.UtcNow);
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.DeleteCommentAsync(stranger.Id, post.Id, comment.Id, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.DeleteCommentAsync(owner.Id, post.Id, otherComment.Id, default));
        await service.DeleteCommentAsync(owner.Id, post.Id, comment.Id, default);

        var stored = await context.PostComments.IgnoreQueryFilters().SingleAsync(x => x.Id == comment.Id);
        Assert.True(stored.IsDeleted);
        Assert.NotNull(stored.DeletedAt);
        Assert.Empty((await service.GetCommentsAsync(owner.Id, post.Id, new(), default)).Items);
        Assert.Equal(0, (await service.GetByIdAsync(owner.Id, post.Id, default)).CommentCount);
    }

    private static CommunityService Service(MotoHubDbContext context) => new(context);

    private static User AddUser(MotoHubDbContext context, string userName, string? firstName = null, string? lastName = null, string? image = null)
    {
        var user = new User
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = $"{userName}@example.com",
            NormalizedEmail = $"{userName}@EXAMPLE.COM",
            FirstName = firstName,
            LastName = lastName,
            ProfileImageUrl = image
        };
        context.Users.Add(user);
        return user;
    }

    private static Post AddPost(
        MotoHubDbContext context,
        User author,
        string content,
        DateTimeOffset publishedAt,
        PostStatus status = PostStatus.Published,
        bool isDeleted = false)
    {
        var post = new Post
        {
            AuthorUserId = author.Id,
            Author = author,
            Content = content,
            Status = status,
            PublishedAt = publishedAt,
            IsDeleted = isDeleted,
            DeletedAt = isDeleted ? DateTimeOffset.UtcNow : null
        };
        context.Posts.Add(post);
        return post;
    }

    private static PostComment AddComment(
        MotoHubDbContext context,
        Post post,
        User author,
        string content,
        DateTimeOffset createdAt,
        PostComment? parent = null)
    {
        var comment = new PostComment
        {
            PostId = post.Id,
            AuthorUserId = author.Id,
            Author = author,
            ParentCommentId = parent?.Id,
            ParentComment = parent,
            Content = content,
            CreatedAt = createdAt,
            UpdatedAt = createdAt
        };
        context.PostComments.Add(comment);
        return comment;
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}