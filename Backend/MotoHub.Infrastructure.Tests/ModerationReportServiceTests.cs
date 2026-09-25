using Microsoft.EntityFrameworkCore;
using MotoHub.Application;
using MotoHub.Application.Errors;
using MotoHub.Application.Moderation;
using MotoHub.Domain;
using MotoHub.Infrastructure.Moderation;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class ModerationReportServiceTests
{
    [Fact]
    public async Task Creates_pending_user_report_with_authenticated_reporter()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var target = AddUser(context, "target");
        await context.SaveChangesAsync();

        var response = await Service(context).CreateAsync(
            reporter.Id,
            new(ModerationReportTargetType.User, target.Id, "spam", "details"),
            default);

        Assert.Equal(ModerationReportTargetType.User, response.TargetType);
        Assert.Equal(target.Id, response.TargetId);
        Assert.Equal(ModerationReportStatus.Pending, response.Status);
        Assert.Equal(reporter.Id, await context.UserReports.Select(x => x.ReporterUserId).SingleAsync());
        Assert.Null(await context.UserReports.Select(x => x.Resolution).SingleAsync());
        Assert.Null(await context.UserReports.Select(x => x.ResolvedByUserId).SingleAsync());
        Assert.Null(await context.UserReports.Select(x => x.ResolvedAt).SingleAsync());
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task Rejects_missing_reason(string? reason)
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var target = AddUser(context, "target");
        await context.SaveChangesAsync();

        await Assert.ThrowsAsync<ValidationException>(() => Service(context).CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, target.Id, reason, null), default));
    }

    [Fact]
    public async Task Rejects_reason_over_100_description_over_5000_and_empty_target_id()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var target = AddUser(context, "target");
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, target.Id, new string('r', 101), null), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, target.Id, "reason", new string('d', 5001)), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, Guid.Empty, "reason", null), default));
    }

    [Fact]
    public async Task Rejects_missing_inactive_or_deleted_reporter()
    {
        await using var context = CreateContext();
        var target = AddUser(context, "target");
        var inactive = AddUser(context, "inactive");
        inactive.IsActive = false;
        var deleted = AddUser(context, "deleted");
        deleted.IsDeleted = true;
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<AuthenticationException>(() => service.CreateAsync(
            Guid.NewGuid(), new(ModerationReportTargetType.User, target.Id, "reason", null), default));
        await Assert.ThrowsAsync<AuthenticationException>(() => service.CreateAsync(
            inactive.Id, new(ModerationReportTargetType.User, target.Id, "reason", null), default));
        await Assert.ThrowsAsync<AuthenticationException>(() => service.CreateAsync(
            deleted.Id, new(ModerationReportTargetType.User, target.Id, "reason", null), default));
    }

    [Fact]
    public async Task Validates_user_target_and_rejects_self_report()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, reporter.Id, "reason", null), default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.CreateAsync(
            reporter.Id, new(ModerationReportTargetType.User, Guid.NewGuid(), "reason", null), default));
    }

    [Fact]
    public async Task Creates_visible_post_comment_and_product_reports_only()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var author = AddUser(context, "author");
        var category = new ProductCategory { Name = "Parts", Slug = "parts" };
        var post = new Post { AuthorUserId = author.Id, Author = author, Content = "post", Status = PostStatus.Published };
        var comment = new PostComment { PostId = post.Id, Post = post, AuthorUserId = author.Id, Author = author, Content = "comment" };
        var product = new Product { SellerUserId = author.Id, Seller = author, CategoryId = category.Id, Category = category, Name = "part", Description = "description", Status = ProductStatus.Active };
        context.ProductCategories.Add(category);
        context.Posts.Add(post);
        context.PostComments.Add(comment);
        context.Products.Add(product);
        context.Users.AddRange(reporter, author);
        await context.SaveChangesAsync();
        var service = Service(context);

        Assert.Equal(ModerationReportTargetType.Post, (await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.Post, post.Id, "reason", null), default)).TargetType);
        Assert.Equal(ModerationReportTargetType.PostComment, (await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.PostComment, comment.Id, "reason", null), default)).TargetType);
        Assert.Equal(ModerationReportTargetType.Product, (await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.Product, product.Id, "reason", null), default)).TargetType);
    }

    [Fact]
    public async Task Rejects_non_visible_post_and_product_targets()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var author = AddUser(context, "author");
        var post = new Post { AuthorUserId = author.Id, Author = author, Content = "draft", Status = PostStatus.Draft };
        context.Users.AddRange(reporter, author);
        context.Posts.Add(post);
        await context.SaveChangesAsync();
        var service = Service(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.CreateAsync(reporter.Id, new(ModerationReportTargetType.Post, post.Id, "reason", null), default));
        post.Status = PostStatus.Published;
        post.IsDeleted = true;
        await context.SaveChangesAsync();
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.CreateAsync(reporter.Id, new(ModerationReportTargetType.Post, post.Id, "reason", null), default));
    }

    [Fact]
    public async Task Message_report_requires_active_conversation_participation_without_private_disclosure()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var other = AddUser(context, "other");
        var stranger = AddUser(context, "stranger");
        var conversation = new Conversation { Type = ConversationType.Direct };
        conversation.Participants.Add(new ConversationParticipant { ConversationId = conversation.Id, UserId = reporter.Id, User = reporter, JoinedAt = DateTimeOffset.UtcNow });
        conversation.Participants.Add(new ConversationParticipant { ConversationId = conversation.Id, UserId = other.Id, User = other, JoinedAt = DateTimeOffset.UtcNow });
        var message = new Message { ConversationId = conversation.Id, Conversation = conversation, SenderUserId = other.Id, Sender = other, Content = "private", MessageType = MessageType.Text, SentAt = DateTimeOffset.UtcNow };
        context.Users.AddRange(reporter, other, stranger);
        context.Conversations.Add(conversation);
        context.Messages.Add(message);
        await context.SaveChangesAsync();
        var service = Service(context);

        Assert.Equal(ModerationReportTargetType.Message, (await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.Message, message.Id, "reason", null), default)).TargetType);
        var exception = await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.CreateAsync(stranger.Id, new(ModerationReportTargetType.Message, message.Id, "reason", null), default));
        Assert.Equal("El mensaje no existe.", exception.Message);
        Assert.DoesNotContain("private", exception.Message);
    }

    [Fact]
    public async Task Active_duplicate_conflicts_but_closed_report_does_not_block_new_report()
    {
        await using var context = CreateContext();
        var reporter = AddUser(context, "reporter");
        var target = AddUser(context, "target");
        await context.SaveChangesAsync();
        var service = Service(context);
        await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.User, target.Id, "first", null), default);

        await Assert.ThrowsAsync<ConflictException>(() => service.CreateAsync(reporter.Id, new(ModerationReportTargetType.User, target.Id, "second", null), default));
        var stored = await context.UserReports.SingleAsync();
        stored.Status = ModerationReportStatus.Resolved;
        await context.SaveChangesAsync();

        var response = await service.CreateAsync(reporter.Id, new(ModerationReportTargetType.User, target.Id, "third", null), default);
        Assert.Equal(ModerationReportStatus.Pending, response.Status);
        Assert.Equal(2, await context.UserReports.CountAsync());
    }

    private static ModerationReportService Service(MotoHubDbContext context) => new(context);

    private static User AddUser(MotoHubDbContext context, string userName)
    {
        var user = new User
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = $"{userName}@example.com",
            NormalizedEmail = $"{userName}@EXAMPLE.COM"
        };
        context.Users.Add(user);
        return user;
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        return new MotoHubDbContext(options);
    }
}