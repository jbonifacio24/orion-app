using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.News;
using MotoHub.Domain;
using MotoHub.Infrastructure.News;
using MotoHub.Infrastructure.Persistence;
using NewsEntity = MotoHub.Domain.News;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class NewsServiceTests
{
    [Fact]
    public async Task Get_feed_returns_only_currently_published_news()
    {
        await using var context = CreateContext();
        var now = DateTimeOffset.UtcNow;
        AddNews(context, "published", now.AddMinutes(-1), NewsStatus.Published);
        AddNews(context, "draft", now.AddMinutes(-2), NewsStatus.Draft);
        AddNews(context, "archived", now.AddMinutes(-3), NewsStatus.Archived);
        AddNews(context, "without-date", null, NewsStatus.Published);
        AddNews(context, "future", now.AddMinutes(1), NewsStatus.Published);
        AddNews(context, "deleted", now.AddMinutes(-4), NewsStatus.Published, isDeleted: true);
        await context.SaveChangesAsync();

        var response = await Service(context).GetFeedAsync(new(), default);

        var item = Assert.Single(response.Items);
        Assert.Equal("published", item.Slug);
        Assert.Equal(1, response.TotalCount);
        Assert.Equal(1, response.TotalPages);
    }

    [Fact]
    public async Task Get_feed_orders_by_published_at_then_id_and_paginates()
    {
        await using var context = CreateContext();
        var now = DateTimeOffset.UtcNow;
        var newest = AddNews(context, "newest", now, NewsStatus.Published);
        var sameTimeA = AddNews(context, "same-a", now.AddMinutes(-1), NewsStatus.Published);
        var sameTimeB = AddNews(context, "same-b", sameTimeA.PublishedAt, NewsStatus.Published);
        AddNews(context, "oldest", now.AddMinutes(-2), NewsStatus.Published);
        await context.SaveChangesAsync();

        var firstPage = await Service(context).GetFeedAsync(new(PageSize: 2), default);
        var secondPage = await Service(context).GetFeedAsync(new(Page: 2, PageSize: 2), default);
        var sameTimeOrder = new[] { sameTimeA.Id, sameTimeB.Id }.OrderByDescending(x => x).ToArray();

        Assert.Equal(new[] { newest.Id, sameTimeOrder[0] }, firstPage.Items.Select(x => x.Id));
        Assert.Equal(new[] { sameTimeOrder[1], context.News.Single(x => x.Slug == "oldest").Id }, secondPage.Items.Select(x => x.Id));
        Assert.Equal(4, firstPage.TotalCount);
        Assert.Equal(2, firstPage.TotalPages);
        Assert.Equal(2, firstPage.PageSize);
    }

    [Fact]
    public async Task Get_feed_returns_multiple_public_categories_in_deterministic_order_and_hides_inactive_categories()
    {
        await using var context = CreateContext();
        var news = AddNews(context, "multi-category", DateTimeOffset.UtcNow, NewsStatus.Published);
        var first = AddCategory(context, "Alpha", "alpha");
        var second = AddCategory(context, "Alpha", "alpha-2");
        var hidden = AddCategory(context, "Hidden", "hidden", isActive: false);
        var deleted = AddCategory(context, "Deleted", "deleted", isDeleted: true);
        context.NewsCategoryAssignments.AddRange(
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = second.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = first.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = hidden.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = deleted.Id });
        await context.SaveChangesAsync();

        var item = Assert.Single((await Service(context).GetFeedAsync(new(), default)).Items);
        var expectedCategories = new[] { first, second }.OrderBy(category => category.Name).ThenBy(category => category.Id).ToArray();

        Assert.Equal(expectedCategories.Select(category => category.Id), item.Categories.Select(x => x.Id));
        Assert.Equal(expectedCategories.Select(category => category.Slug), item.Categories.Select(x => x.Slug));
        Assert.DoesNotContain(item.Categories, category => category.Slug == "hidden");
        Assert.DoesNotContain(item.Categories, category => category.Slug == "deleted");
    }

    [Fact]
    public async Task Get_feed_category_filter_returns_only_matching_news_and_invalid_categories_are_empty()
    {
        await using var context = CreateContext();
        var active = AddCategory(context, "Active", "active");
        var inactive = AddCategory(context, "Inactive", "inactive", isActive: false);
        var deleted = AddCategory(context, "Deleted", "deleted", isDeleted: true);
        var included = AddNews(context, "included", DateTimeOffset.UtcNow, NewsStatus.Published);
        var excluded = AddNews(context, "excluded", DateTimeOffset.UtcNow.AddMinutes(-1), NewsStatus.Published);
        context.NewsCategoryAssignments.AddRange(
            new NewsCategoryAssignment { NewsId = included.Id, NewsCategoryId = active.Id },
            new NewsCategoryAssignment { NewsId = excluded.Id, NewsCategoryId = inactive.Id });
        await context.SaveChangesAsync();

        var matching = await Service(context).GetFeedAsync(new(CategoryId: active.Id), default);
        var inactiveResult = await Service(context).GetFeedAsync(new(CategoryId: inactive.Id), default);
        var deletedResult = await Service(context).GetFeedAsync(new(CategoryId: deleted.Id), default);
        var missingResult = await Service(context).GetFeedAsync(new(CategoryId: Guid.NewGuid()), default);

        Assert.Equal(new[] { included.Id }, matching.Items.Select(x => x.Id));
        Assert.Empty(inactiveResult.Items);
        Assert.Empty(deletedResult.Items);
        Assert.Empty(missingResult.Items);
    }

    [Fact]
    public async Task Get_categories_returns_active_categories_including_empty_categories()
    {
        await using var context = CreateContext();
        var beta = AddCategory(context, "Beta", "beta");
        var alpha = AddCategory(context, "Alpha", "alpha");
        AddCategory(context, "Inactive", "inactive", isActive: false);
        AddCategory(context, "Deleted", "deleted", isDeleted: true);
        await context.SaveChangesAsync();

        var categories = await Service(context).GetCategoriesAsync(default);

        Assert.Equal(new[] { alpha.Id, beta.Id }, categories.Select(x => x.Id));
        Assert.Equal(new[] { "alpha", "beta" }, categories.Select(x => x.Slug));
    }

    [Fact]
    public async Task Get_feed_validates_page_and_page_size()
    {
        await using var context = CreateContext();
        var service = Service(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(new(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(new(PageSize: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetFeedAsync(new(PageSize: 51), default));
    }

    [Fact]
    public async Task Get_feed_summary_does_not_expose_internal_fields_or_content()
    {
        await using var context = CreateContext();
        AddNews(context, "public", DateTimeOffset.UtcNow, NewsStatus.Published, summary: "Summary", content: "Private content");
        await context.SaveChangesAsync();

        var item = Assert.Single((await Service(context).GetFeedAsync(new(), default)).Items);
        var json = JsonSerializer.Serialize(item);

        Assert.Equal("Summary", item.Summary);
        Assert.DoesNotContain("Private content", json);
        Assert.DoesNotContain(nameof(NewsEntity.Content), json);
        Assert.DoesNotContain(nameof(NewsEntity.AuthorUserId), json);
        Assert.DoesNotContain(nameof(NewsEntity.Status), json);
        Assert.DoesNotContain(nameof(NewsEntity.RowVersion), json);
        Assert.DoesNotContain(nameof(NewsEntity.IsDeleted), json);
        Assert.DoesNotContain(nameof(NewsEntity.DeletedAt), json);
        Assert.DoesNotContain(nameof(NewsEntity.UpdatedAt), json);
    }

    [Fact]
    public async Task Get_detail_returns_public_news_with_content_and_public_categories_in_order()
    {
        await using var context = CreateContext();
        var news = AddNews(
            context,
            "detail",
            DateTimeOffset.UtcNow.AddMinutes(-1),
            NewsStatus.Published,
            summary: "Summary",
            content: "Full article content",
            featuredImageUrl: "https://cdn.example.test/detail.jpg");
        var first = AddCategory(context, "Alpha", "alpha");
        var second = AddCategory(context, "Alpha", "alpha-2");
        var inactive = AddCategory(context, "Inactive", "inactive", isActive: false);
        var deleted = AddCategory(context, "Deleted", "deleted", isDeleted: true);
        context.NewsCategoryAssignments.AddRange(
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = second.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = deleted.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = first.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = inactive.Id });
        await context.SaveChangesAsync();

        var detail = await Service(context).GetByIdAsync(news.Id, default);

        Assert.Equal(news.Id, detail.Id);
        Assert.Equal("detail", detail.Slug);
        Assert.Equal("detail", detail.Title);
        Assert.Equal("Summary", detail.Summary);
        Assert.Equal("Full article content", detail.Content);
        Assert.Equal("https://cdn.example.test/detail.jpg", detail.FeaturedImageUrl);
        Assert.Equal(news.PublishedAt, detail.PublishedAt);
        var expectedCategories = new[] { first, second }
            .OrderBy(category => category.Name)
            .ThenBy(category => category.Id)
            .ToArray();
        Assert.Equal(expectedCategories.Select(category => category.Id), detail.Categories.Select(x => x.Id));
        Assert.Equal(expectedCategories.Select(category => category.Slug), detail.Categories.Select(x => x.Slug));
    }

    [Fact]
    public async Task Get_detail_returns_empty_categories_when_no_public_category_exists()
    {
        await using var context = CreateContext();
        var news = AddNews(context, "without-public-category", DateTimeOffset.UtcNow, NewsStatus.Published);
        var inactive = AddCategory(context, "Inactive", "inactive", isActive: false);
        var deleted = AddCategory(context, "Deleted", "deleted", isDeleted: true);
        context.NewsCategoryAssignments.AddRange(
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = inactive.Id },
            new NewsCategoryAssignment { NewsId = news.Id, NewsCategoryId = deleted.Id });
        await context.SaveChangesAsync();

        var detail = await Service(context).GetByIdAsync(news.Id, default);

        Assert.Empty(detail.Categories);
    }

    [Fact]
    public async Task Get_detail_does_not_expose_non_public_news()
    {
        await using var context = CreateContext();
        var draft = AddNews(context, "draft-detail", DateTimeOffset.UtcNow, NewsStatus.Draft);
        var archived = AddNews(context, "archived-detail", DateTimeOffset.UtcNow, NewsStatus.Archived);
        var withoutDate = AddNews(context, "without-date-detail", null, NewsStatus.Published);
        var future = AddNews(context, "future-detail", DateTimeOffset.UtcNow.AddMinutes(1), NewsStatus.Published);
        var deleted = AddNews(context, "deleted-detail", DateTimeOffset.UtcNow, NewsStatus.Published, isDeleted: true);
        await context.SaveChangesAsync();

        var ids = new[] { Guid.NewGuid(), draft.Id, archived.Id, withoutDate.Id, future.Id, deleted.Id };

        foreach (var id in ids)
        {
            await Assert.ThrowsAsync<ResourceNotFoundException>(() => Service(context).GetByIdAsync(id, default));
        }
    }

    [Fact]
    public async Task Get_detail_dto_exposes_content_but_not_internal_fields()
    {
        await using var context = CreateContext();
        var news = AddNews(context, "private-fields", DateTimeOffset.UtcNow, NewsStatus.Published, content: "Visible content");
        await context.SaveChangesAsync();

        var detail = await Service(context).GetByIdAsync(news.Id, default);
        var json = JsonSerializer.Serialize(detail, new JsonSerializerOptions { PropertyNamingPolicy = null });

        Assert.Contains("Visible content", json);
        Assert.Contains(nameof(NewsEntity.Content), json);
        Assert.DoesNotContain(nameof(NewsEntity.AuthorUserId), json);
        Assert.DoesNotContain(nameof(NewsEntity.RowVersion), json);
        Assert.DoesNotContain(nameof(NewsEntity.IsDeleted), json);
        Assert.DoesNotContain(nameof(NewsEntity.DeletedAt), json);
        Assert.DoesNotContain(nameof(NewsEntity.Status), json);
        Assert.DoesNotContain(nameof(NewsEntity.CreatedAt), json);
        Assert.DoesNotContain(nameof(NewsEntity.UpdatedAt), json);
    }

    private static NewsService Service(MotoHubDbContext context) => new(context);

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }

    private static NewsEntity AddNews(
        MotoHubDbContext context,
        string slug,
        DateTimeOffset? publishedAt,
        NewsStatus status,
        bool isDeleted = false,
        string? summary = null,
        string content = "Content",
        string? featuredImageUrl = null)
    {
        var news = new NewsEntity
        {
            Title = slug,
            Slug = slug,
            Summary = summary,
            Content = content,
            FeaturedImageUrl = featuredImageUrl,
            Status = status,
            PublishedAt = publishedAt,
            IsDeleted = isDeleted,
            DeletedAt = isDeleted ? DateTimeOffset.UtcNow : null
        };
        context.News.Add(news);
        return news;
    }

    private static NewsCategory AddCategory(
        MotoHubDbContext context,
        string name,
        string slug,
        bool isActive = true,
        bool isDeleted = false)
    {
        var category = new NewsCategory
        {
            Name = name,
            Slug = slug,
            IsActive = isActive,
            IsDeleted = isDeleted,
            DeletedAt = isDeleted ? DateTimeOffset.UtcNow : null
        };
        context.NewsCategories.Add(category);
        return category;
    }
}