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

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}