using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Motorcycles;
using MotoHub.Application.Profile;
using MotoHub.Domain;
using MotoHub.Infrastructure.Motorcycles;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Profile;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class ProfileAndMotorcycleServiceTests
{
    [Fact]
    public async Task Profile_update_changes_only_allowed_fields()
    {
        await using var context = CreateContext();
        var userId = Guid.NewGuid();
        context.Users.Add(new User(userId)
        {
            UserName = "rider",
            Email = "rider@example.com",
            FirstName = "Old",
            LastName = "Name",
            ProfileImageUrl = "https://image.example/profile.png"
        });
        await context.SaveChangesAsync();

        var service = new ProfileService(context);
        var result = await service.UpdateAsync(userId, new UpdateProfileRequestDto(" New ", "Rider", "123", "Bio"), default);

        Assert.Equal("New", result.FirstName);
        Assert.Equal("Rider", result.LastName);
        Assert.Equal("123", result.PhoneNumber);
        Assert.Equal("Bio", result.Bio);
        Assert.Equal("https://image.example/profile.png", result.ProfileImageUrl);
        Assert.Equal("rider@example.com", result.Email);
    }

    [Fact]
    public async Task Profile_update_rejects_invalid_length()
    {
        await using var context = CreateContext();
        var service = new ProfileService(context);

        var exception = await Assert.ThrowsAsync<ValidationException>(() => service.UpdateAsync(
            Guid.NewGuid(),
            new UpdateProfileRequestDto(new string('x', 101), null, null, null),
            default));

        Assert.Contains("FirstName", exception.Message);
    }

    [Fact]
    public async Task Motorcycle_operations_filter_by_owner_and_soft_delete()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var otherOwnerId = Guid.NewGuid();
        var service = new MotorcycleService(context);
        var own = await service.CreateAsync(ownerId, Request("Own", isPrimary: false), default);
        await service.CreateAsync(otherOwnerId, Request("Other", isPrimary: false), default);
        context.MotorcycleImages.Add(new MotorcycleImage
        {
            MotorcycleId = own.Id,
            Url = "https://image.example/motorcycle.jpg",
            StorageKey = "existing-image",
            DisplayOrder = 0
        });
        await context.SaveChangesAsync();

        Assert.Single(await service.GetMineAsync(ownerId, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetByIdAsync(otherOwnerId, own.Id, default));

        await service.DeleteAsync(ownerId, own.Id, default);

        Assert.Empty(await service.GetMineAsync(ownerId, default));
        var deleted = await context.Motorcycles.IgnoreQueryFilters().SingleAsync(x => x.Id == own.Id);
        Assert.True(deleted.IsDeleted);
        Assert.NotNull(deleted.DeletedAt);
        Assert.Single(deleted.Images);
    }

    [Fact]
    public void Db_update_concurrency_exception_is_classified_as_conflict()
    {
        var exception = new DbUpdateConcurrencyException("Concurrency conflict.");

        Assert.True(MotorcycleConflictClassifier.IsConcurrencyConflict(exception));
    }

    [Theory]
    [InlineData("IX_Motorcycles_Vin")]
    [InlineData("IX_Motorcycles_OwnerUserId_IsPrimary")]
    public void Known_sql_unique_constraints_are_classified_as_conflicts(string indexName)
    {
        Assert.True(MotorcycleConflictClassifier.IsKnownUniqueConstraint(2601, $"Violation of unique index {indexName}."));
        Assert.True(MotorcycleConflictClassifier.IsKnownUniqueConstraint(2627, $"Violation of unique constraint {indexName}."));
    }

    [Theory]
    [InlineData(547, "The INSERT statement conflicted with a FOREIGN KEY constraint.")]
    [InlineData(2601, "Violation of unique index IX_OtherTable_OtherIndex.")]
    public void Unknown_sql_errors_are_not_classified_as_motorcycle_conflicts(int sqlErrorNumber, string message)
    {
        Assert.False(MotorcycleConflictClassifier.IsKnownUniqueConstraint(sqlErrorNumber, message));
    }

    [Fact]
    public async Task First_motorcycle_is_primary_and_primary_delete_promotes_deterministically()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var service = new MotorcycleService(context);
        var first = await service.CreateAsync(ownerId, Request("First", isPrimary: false), default);
        var second = await service.CreateAsync(ownerId, Request("Second", isPrimary: false), default);

        Assert.True(first.IsPrimary);
        Assert.False(second.IsPrimary);

        await service.DeleteAsync(ownerId, first.Id, default);

        var remaining = await service.GetMineAsync(ownerId, default);
        Assert.Single(remaining);
        Assert.True(remaining.Single().IsPrimary);
    }

    [Fact]
    public async Task Primary_update_replaces_the_previous_primary()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var service = new MotorcycleService(context);
        var first = await service.CreateAsync(ownerId, Request("First", isPrimary: false), default);
        var second = await service.CreateAsync(ownerId, Request("Second", isPrimary: false), default);

        var updated = await service.UpdateAsync(ownerId, second.Id, UpdateRequest("Second", isPrimary: true), default);

        Assert.True(updated.IsPrimary);
        Assert.False((await service.GetByIdAsync(ownerId, first.Id, default)).IsPrimary);
        Assert.Single(await service.GetMineAsync(ownerId, default), x => x.IsPrimary);
    }

    [Fact]
    public async Task Creating_primary_motorcycle_replaces_previous_primary()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var service = new MotorcycleService(context);
        var first = await service.CreateAsync(ownerId, Request("First", isPrimary: false), default);

        var second = await service.CreateAsync(ownerId, Request("Second", isPrimary: true), default);

        Assert.True(second.IsPrimary);
        Assert.False((await service.GetByIdAsync(ownerId, first.Id, default)).IsPrimary);
        Assert.Single(await service.GetMineAsync(ownerId, default), x => x.IsPrimary);
    }

    [Fact]
    public async Task Duplicate_vin_returns_conflict()
    {
        await using var context = CreateContext();
        var service = new MotorcycleService(context);
        await service.CreateAsync(Guid.NewGuid(), Request("First", vin: "VIN-1"), default);

        var exception = await Assert.ThrowsAsync<ConflictException>(() => service.CreateAsync(
            Guid.NewGuid(), Request("Second", vin: "VIN-1"), default));

        Assert.Contains("VIN", exception.Message);
    }

    [Fact]
    public async Task Motorcycle_response_projects_existing_images()
    {
        await using var context = CreateContext();
        var ownerId = Guid.NewGuid();
        var motorcycle = new Motorcycle
        {
            OwnerUserId = ownerId,
            Brand = "Brand",
            Model = "Model",
            Year = 2020,
            IsPrimary = true,
            Images =
            {
                new MotorcycleImage
                {
                    Url = "https://image.example/full.jpg",
                    ThumbnailUrl = "https://image.example/thumb.jpg",
                    DisplayOrder = 1,
                    IsPrimary = true,
                    StorageKey = "existing"
                }
            }
        };
        context.Motorcycles.Add(motorcycle);
        await context.SaveChangesAsync();

        var result = await new MotorcycleService(context).GetByIdAsync(ownerId, motorcycle.Id, default);

        var image = Assert.Single(result.Images);
        Assert.Equal("https://image.example/full.jpg", image.Url);
        Assert.Equal("https://image.example/thumb.jpg", image.ThumbnailUrl);
        Assert.True(image.IsPrimary);
    }

    private static CreateMotorcycleRequestDto Request(string brand, bool isPrimary = false, string? vin = null)
        => new(brand, "Model", 2020, 500, "Black", null, vin, null, isPrimary);

    private static UpdateMotorcycleRequestDto UpdateRequest(string brand, bool isPrimary = false, string? vin = null)
        => new(brand, "Model", 2020, 500, "Black", null, vin, null, isPrimary);

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new MotoHubDbContext(options);
    }
}
