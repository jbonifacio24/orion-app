using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Workshops;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using InfrastructureWorkshopService = MotoHub.Infrastructure.Workshops.WorkshopService;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class WorkshopServiceTests
{
    [Fact]
    public async Task List_returns_only_active_non_deleted_workshops_with_deterministic_pagination()
    {
        await using var context = CreateContext();
        var first = AddWorkshop(context, "Alpha", WorkshopStatus.Active);
        var second = AddWorkshop(context, "Beta", WorkshopStatus.Active);
        AddWorkshop(context, "Pending", WorkshopStatus.Pending);
        AddWorkshop(context, "Suspended", WorkshopStatus.Suspended);
        AddWorkshop(context, "Archived", WorkshopStatus.Archived);
        AddWorkshop(context, "Deleted", WorkshopStatus.Active, isDeleted: true);
        await context.SaveChangesAsync();

        var result = await new InfrastructureWorkshopService(context).GetWorkshopsAsync(new(Page: 1, PageSize: 1), default);

        Assert.Equal(2, result.TotalCount);
        Assert.Equal(2, result.TotalPages);
        Assert.Single(result.Items);
        Assert.Equal(first.Id, result.Items.Single().Id);
        Assert.Equal(second.Name, (await new InfrastructureWorkshopService(context).GetWorkshopsAsync(new(Page: 2, PageSize: 1), default)).Items.Single().Name);
    }

    [Fact]
    public async Task List_searches_name_city_and_address_and_filters_city()
    {
        await using var context = CreateContext();
        AddWorkshop(context, "Moto Norte", WorkshopStatus.Active, city: "Lima", address: "Avenida Central");
        AddWorkshop(context, "Moto Sur", WorkshopStatus.Active, city: "Cusco", address: "Taller Central");
        await context.SaveChangesAsync();
        var service = new InfrastructureWorkshopService(context);

        var byName = await service.GetWorkshopsAsync(new(Search: "Norte"), default);
        var byAddress = await service.GetWorkshopsAsync(new(Search: "Taller"), default);
        var byCity = await service.GetWorkshopsAsync(new(City: "Cusco"), default);

        Assert.Single(byName.Items);
        Assert.Single(byAddress.Items);
        Assert.Equal("Moto Sur", byCity.Items.Single().Name);
    }

    [Fact]
    public async Task List_returns_empty_result_and_rejects_invalid_pagination()
    {
        await using var context = CreateContext();
        var service = new InfrastructureWorkshopService(context);

        var result = await service.GetWorkshopsAsync(new(), default);

        Assert.Empty(result.Items);
        Assert.Equal(0, result.TotalCount);
        Assert.Equal(0, result.TotalPages);
        await Assert.ThrowsAsync<ValidationException>(() => service.GetWorkshopsAsync(new(Page: 0), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.GetWorkshopsAsync(new(PageSize: 51), default));
    }

    [Fact]
    public async Task Detail_returns_public_data_and_filters_services_reviews_and_calculates_rating()
    {
        await using var context = CreateContext();
        var workshop = AddWorkshop(context, "Moto Detail", WorkshopStatus.Active);
        workshop.Schedules.Add(new WorkshopSchedule { DayOfWeek = 2, OpenTime = new TimeOnly(10, 0), CloseTime = new TimeOnly(12, 0) });
        workshop.Schedules.Add(new WorkshopSchedule { DayOfWeek = 1, IsClosed = true });
        workshop.Services.Add(new MotoHub.Domain.WorkshopService { Name = "Oil change", IsActive = true });
        workshop.Services.Add(new MotoHub.Domain.WorkshopService { Name = "Disabled", IsActive = false });
        workshop.Services.Add(new MotoHub.Domain.WorkshopService { Name = "Deleted", IsActive = true, IsDeleted = true });
        var author = AddUser(context, "reviewer", "Ana", "Rider");
        var secondAuthor = AddUser(context, "second-reviewer");
        var thirdAuthor = AddUser(context, "third-reviewer");
        var fourthAuthor = AddUser(context, "fourth-reviewer");
        context.WorkshopReviews.AddRange(
            new WorkshopReview { WorkshopId = workshop.Id, AuthorUserId = author.Id, Rating = 5, Comment = "Great", Status = ReviewStatus.Published },
            new WorkshopReview { WorkshopId = workshop.Id, AuthorUserId = secondAuthor.Id, Rating = 3, Comment = "Good", Status = ReviewStatus.Published },
            new WorkshopReview { WorkshopId = workshop.Id, AuthorUserId = thirdAuthor.Id, Rating = 1, Status = ReviewStatus.Pending },
            new WorkshopReview { WorkshopId = workshop.Id, AuthorUserId = fourthAuthor.Id, Rating = 2, Status = ReviewStatus.Published, IsDeleted = true });
        await context.SaveChangesAsync();

        var result = await new InfrastructureWorkshopService(context).GetWorkshopByIdAsync(workshop.Id, default);

        Assert.Equal(2, result.Schedules.Count);
        Assert.Equal(1, result.Schedules.First().DayOfWeek);
        Assert.Single(result.Services);
        Assert.Single(result.Reviews, review => review.Rating == 5);
        Assert.Equal(2, result.Reviews.Count);
        Assert.Equal(4m, result.AverageRating);
        Assert.Equal(2, result.ReviewCount);
        Assert.DoesNotContain("OwnerUserId", string.Join(',', typeof(WorkshopDetailResponseDto).GetProperties().Select(property => property.Name)));
        Assert.DoesNotContain("AuthorUserId", string.Join(',', typeof(WorkshopReviewResponseDto).GetProperties().Select(property => property.Name)));
    }

    [Fact]
    public async Task Detail_returns_not_found_for_invisible_or_missing_workshops()
    {
        await using var context = CreateContext();
        var pending = AddWorkshop(context, "Pending", WorkshopStatus.Pending);
        var deleted = AddWorkshop(context, "Deleted", WorkshopStatus.Active, isDeleted: true);
        await context.SaveChangesAsync();
        var service = new InfrastructureWorkshopService(context);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetWorkshopByIdAsync(Guid.NewGuid(), default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetWorkshopByIdAsync(pending.Id, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetWorkshopByIdAsync(deleted.Id, default));
    }

    [Fact]
    public async Task Detail_limits_reviews_but_calculates_rating_over_all_published_reviews()
    {
        await using var context = CreateContext();
        var workshop = AddWorkshop(context, "Many reviews", WorkshopStatus.Active);
        for (var index = 0; index < 21; index++)
        {
            var author = AddUser(context, $"reviewer-{index}");
            context.WorkshopReviews.Add(new WorkshopReview
            {
                WorkshopId = workshop.Id,
                AuthorUserId = author.Id,
                Rating = index == 20 ? 1 : 5,
                Status = ReviewStatus.Published,
                CreatedAt = DateTimeOffset.UtcNow.AddMinutes(-index)
            });
        }
        await context.SaveChangesAsync();

        var result = await new InfrastructureWorkshopService(context).GetWorkshopByIdAsync(workshop.Id, default);

        Assert.Equal(20, result.Reviews.Count);
        Assert.Equal(101m / 21m, result.AverageRating);
        Assert.Equal(21, result.ReviewCount);
    }

    private static Workshop AddWorkshop(MotoHubDbContext context, string name, WorkshopStatus status, string? city = null, string? address = null, bool isDeleted = false)
    {
        var workshop = new Workshop
        {
            OwnerUserId = Guid.NewGuid(),
            Name = name,
            City = city,
            Address = address,
            Status = status,
            IsDeleted = isDeleted
        };
        context.Workshops.Add(workshop);
        return workshop;
    }

    private static User AddUser(MotoHubDbContext context, string userName, string? firstName = null, string? lastName = null)
    {
        var user = new User(Guid.NewGuid())
        {
            UserName = userName,
            NormalizedUserName = userName.ToUpperInvariant(),
            Email = $"{userName}@example.com",
            NormalizedEmail = $"{userName}@EXAMPLE.COM",
            FirstName = firstName,
            LastName = lastName
        };
        context.Users.Add(user);
        return user;
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}