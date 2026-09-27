using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerUniqueConstraintTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Critical_unique_indexes_and_filters_exist_in_sql_server()
    {
        await using var context = fixture.CreateContext();
        var indexes = await ReadIndexesAsync(context.Database.GetDbConnection(), new[]
        {
            "Users", "Roles", "RefreshTokens", "Motorcycles", "MotorcycleImages", "ProductImages",
            "ProductFavorites", "MotorcycleFavorites", "WorkshopFavorites", "PostLikes", "ProductReviews",
            "WorkshopReviews", "WorkshopSchedules", "WorkshopServices", "News", "NewsCategories",
            "Referrals", "ReferralRewards", "SubscriptionPlans", "Subscriptions", "UserDevices"
        });

        AssertUnique(indexes, "Users", ["NormalizedEmail"]);
        AssertUnique(indexes, "Users", ["NormalizedUserName"]);
        AssertUnique(indexes, "Users", ["PhoneNumber"], "PhoneNumber IS NOT NULL");
        AssertUnique(indexes, "Roles", ["NormalizedName"]);
        AssertUnique(indexes, "RefreshTokens", ["TokenHash"]);
        AssertUnique(indexes, "Motorcycles", ["Vin"], "Vin IS NOT NULL AND IsDeleted = 0");
        AssertUnique(indexes, "Motorcycles", ["OwnerUserId", "IsPrimary"], "IsPrimary = 1 AND IsDeleted = 0");
        AssertUnique(indexes, "MotorcycleImages", ["MotorcycleId", "DisplayOrder"]);
        AssertUnique(indexes, "MotorcycleImages", ["MotorcycleId", "IsPrimary"], "IsPrimary = 1");
        AssertPrimaryKey(indexes, "ProductFavorites", ["UserId", "ProductId"]);
        AssertPrimaryKey(indexes, "MotorcycleFavorites", ["UserId", "MotorcycleId"]);
        AssertPrimaryKey(indexes, "WorkshopFavorites", ["UserId", "WorkshopId"]);
        AssertPrimaryKey(indexes, "PostLikes", ["PostId", "UserId"]);
        AssertUnique(indexes, "ProductImages", ["ProductId", "DisplayOrder"]);
        AssertUnique(indexes, "ProductImages", ["ProductId", "IsPrimary"], "IsPrimary = 1");
        AssertUnique(indexes, "ProductReviews", ["AuthorUserId", "ProductId"]);
        AssertUnique(indexes, "WorkshopReviews", ["AuthorUserId", "WorkshopId"]);
        AssertUnique(indexes, "WorkshopSchedules", ["WorkshopId", "DayOfWeek", "OpenTime", "CloseTime"], "OpenTime IS NOT NULL AND CloseTime IS NOT NULL");
        AssertUnique(indexes, "WorkshopServices", ["WorkshopId", "Name"]);
        AssertUnique(indexes, "News", ["Slug"]);
        AssertUnique(indexes, "NewsCategories", ["Slug"]);
        AssertUnique(indexes, "Referrals", ["Code"]);
        AssertUnique(indexes, "ReferralRewards", ["ReferralId", "RewardType"]);
        AssertUnique(indexes, "SubscriptionPlans", ["Code"]);
        AssertUnique(indexes, "Subscriptions", ["ProviderSubscriptionId"]);
        AssertUnique(indexes, "Subscriptions", ["UserId"], "Status = 'Active'");
        AssertUnique(indexes, "UserDevices", ["UserId", "DeviceId"]);
        AssertUnique(indexes, "UserDevices", ["PushTokenCiphertext"]);
    }

    [Fact]
    public async Task Motorcycle_filtered_vin_and_primary_indexes_enforce_sql_uniqueness()
    {
        var ownerId = await CreateUserAsync("motorcycle");
        var vin = $"VIN-{Guid.NewGuid():N}";
        var primaryMotorcycleId = await CreateMotorcycleAsync(ownerId, vin, true);

        await AssertDuplicateAsync(async context =>
        {
            context.Motorcycles.Add(new Motorcycle { OwnerUserId = ownerId, Brand = "B", Model = "M", Year = 2024, Vin = vin });
            await context.SaveChangesAsync();
        });
        await AssertDuplicateAsync(async context =>
        {
            context.Motorcycles.Add(new Motorcycle { OwnerUserId = ownerId, Brand = "B", Model = "M2", Year = 2024, IsPrimary = true, Vin = $"VIN-{Guid.NewGuid():N}" });
            await context.SaveChangesAsync();
        });

        await using (var context = fixture.CreateContext())
        {
            var motorcycle = await context.Motorcycles.IgnoreQueryFilters().SingleAsync(x => x.Id == primaryMotorcycleId);
            motorcycle.IsDeleted = true;
            await context.SaveChangesAsync();
        }

        await CreateMotorcycleAsync(ownerId, vin, true);

        await CreateMotorcycleAsync(ownerId, null, false);
        await CreateMotorcycleAsync(ownerId, null, false);
    }

    [Fact]
    public async Task Product_image_indexes_enforce_display_order_and_primary_uniqueness()
    {
        var (productId, _) = await CreateProductAsync("product-image");
        await CreateProductImageAsync(productId, 0, true);

        await AssertDuplicateAsync(async context =>
        {
            context.ProductImages.Add(new ProductImage { ProductId = productId, StorageKey = "duplicate-order", Url = "https://example.test/order", DisplayOrder = 0 });
            await context.SaveChangesAsync();
        });
        await AssertDuplicateAsync(async context =>
        {
            context.ProductImages.Add(new ProductImage { ProductId = productId, StorageKey = "duplicate-primary", Url = "https://example.test/primary", DisplayOrder = 1, IsPrimary = true });
            await context.SaveChangesAsync();
        });
    }

    [Fact]
    public async Task Workshop_schedule_filter_allows_duplicate_closed_schedules_with_null_times()
    {
        var ownerId = await CreateUserAsync("workshop-schedule");
        await using (var context = fixture.CreateContext())
        {
            var workshop = new Workshop { OwnerUserId = ownerId, Name = $"Workshop {Guid.NewGuid():N}", Status = WorkshopStatus.Active };
            context.Workshops.Add(workshop);
            await context.SaveChangesAsync();

            await CreateWorkshopScheduleAsync(workshop.Id, new TimeOnly(9, 0), new TimeOnly(17, 0), false);
            await AssertDuplicateWorkshopScheduleAsync(workshop.Id, new TimeOnly(9, 0), new TimeOnly(17, 0), false);
            await CreateWorkshopScheduleAsync(workshop.Id, null, null, true);
            await CreateWorkshopScheduleAsync(workshop.Id, null, null, true);
        }
    }

    [Fact]
    public async Task Composite_keys_and_reviews_reject_sequential_duplicates()
    {
        var (productId, ownerId) = await CreateProductAsync("favorites");
        await using (var context = fixture.CreateContext())
        {
            context.ProductFavorites.Add(new ProductFavorite { UserId = ownerId, ProductId = productId });
            await context.SaveChangesAsync();
        }
        await AssertDuplicateAsync(async context =>
        {
            context.ProductFavorites.Add(new ProductFavorite { UserId = ownerId, ProductId = productId });
            await context.SaveChangesAsync();
        });

        await using (var context = fixture.CreateContext())
        {
            context.ProductReviews.Add(new ProductReview { AuthorUserId = ownerId, ProductId = productId, Rating = 5, Status = ReviewStatus.Published });
            await context.SaveChangesAsync();
        }
        await AssertDuplicateAsync(async context =>
        {
            context.ProductReviews.Add(new ProductReview { AuthorUserId = ownerId, ProductId = productId, Rating = 4, Status = ReviewStatus.Pending });
            await context.SaveChangesAsync();
        });
    }

    [Fact]
    public async Task Subscription_active_filter_and_token_indexes_reject_duplicates()
    {
        var userId = await CreateUserAsync("subscription");
        var planId = await CreateSubscriptionPlanAsync();
        await CreateSubscriptionAsync(userId, planId, "provider-subscription");

        await AssertDuplicateAsync(async context =>
        {
            context.Subscriptions.Add(NewSubscription(userId, planId, "provider-subscription-2"));
            await context.SaveChangesAsync();
        });

        await using (var context = fixture.CreateContext())
        {
            context.Subscriptions.Add(NewSubscription(userId, planId, "provider-subscription-cancelled", SubscriptionStatus.Cancelled));
            await context.SaveChangesAsync();
        }

        var otherUserId = await CreateUserAsync("subscription-other");
        await CreateSubscriptionAsync(otherUserId, planId, "provider-subscription-other");
    }

    private async Task<Guid> CreateUserAsync(string prefix)
    {
        await using var context = fixture.CreateContext();
        var user = NewUser(prefix);
        context.Users.Add(user);
        await context.SaveChangesAsync();
        return user.Id;
    }

    private async Task<Guid> CreateMotorcycleAsync(Guid ownerId, string? vin, bool isPrimary)
    {
        await using var context = fixture.CreateContext();
        var motorcycle = new Motorcycle { OwnerUserId = ownerId, Brand = "Brand", Model = Guid.NewGuid().ToString("N"), Year = 2024, Vin = vin, IsPrimary = isPrimary };
        context.Motorcycles.Add(motorcycle);
        await context.SaveChangesAsync();
        return motorcycle.Id;
    }

    private async Task<(Guid ProductId, Guid OwnerId)> CreateProductAsync(string prefix)
    {
        await using var context = fixture.CreateContext();
        var owner = NewUser(prefix);
        var category = new ProductCategory { Name = $"Category {Guid.NewGuid():N}", Slug = $"category-{Guid.NewGuid():N}" };
        var product = new Product { Seller = owner, Category = category, Name = $"Product {Guid.NewGuid():N}", Description = "Test product", Condition = ProductCondition.New, Status = ProductStatus.Draft };
        context.Products.Add(product);
        await context.SaveChangesAsync();
        return (product.Id, owner.Id);
    }

    private async Task CreateProductImageAsync(Guid productId, int displayOrder, bool isPrimary)
    {
        await using var context = fixture.CreateContext();
        context.ProductImages.Add(new ProductImage { ProductId = productId, StorageKey = Guid.NewGuid().ToString("N"), Url = "https://example.test/image", DisplayOrder = displayOrder, IsPrimary = isPrimary });
        await context.SaveChangesAsync();
    }

    private async Task CreateWorkshopScheduleAsync(Guid workshopId, TimeOnly? openTime, TimeOnly? closeTime, bool isClosed)
    {
        await using var context = fixture.CreateContext();
        context.WorkshopSchedules.Add(new WorkshopSchedule { WorkshopId = workshopId, DayOfWeek = 1, OpenTime = openTime, CloseTime = closeTime, IsClosed = isClosed });
        await context.SaveChangesAsync();
    }

    private async Task AssertDuplicateWorkshopScheduleAsync(Guid workshopId, TimeOnly? openTime, TimeOnly? closeTime, bool isClosed)
    {
        await AssertDuplicateAsync(async context =>
        {
            context.WorkshopSchedules.Add(new WorkshopSchedule { WorkshopId = workshopId, DayOfWeek = 1, OpenTime = openTime, CloseTime = closeTime, IsClosed = isClosed });
            await context.SaveChangesAsync();
        });
    }

    private async Task<Guid> CreateSubscriptionPlanAsync()
    {
        await using var context = fixture.CreateContext();
        var plan = new SubscriptionPlan { Code = $"plan-{Guid.NewGuid():N}", Name = "Test plan", Price = 10m, Currency = "EUR" };
        context.SubscriptionPlans.Add(plan);
        await context.SaveChangesAsync();
        return plan.Id;
    }

    private async Task CreateSubscriptionAsync(Guid userId, Guid planId, string providerId)
    {
        await using var context = fixture.CreateContext();
        context.Subscriptions.Add(NewSubscription(userId, planId, providerId));
        await context.SaveChangesAsync();
    }

    private static Subscription NewSubscription(Guid userId, Guid planId, string providerId, SubscriptionStatus status = SubscriptionStatus.Active)
    {
        var start = DateTimeOffset.UtcNow;
        return new Subscription { UserId = userId, SubscriptionPlanId = planId, Status = status, Provider = SubscriptionProvider.Stripe, ProviderSubscriptionId = providerId, StartedAt = start, CurrentPeriodStart = start, CurrentPeriodEnd = start.AddDays(30) };
    }

    private static User NewUser(string prefix)
    {
        var suffix = Guid.NewGuid().ToString("N");
        return new User { UserName = $"{prefix}-{suffix}", NormalizedUserName = $"{prefix}-{suffix}".ToUpperInvariant(), Email = $"{prefix}-{suffix}@example.test", NormalizedEmail = $"{prefix}-{suffix}@EXAMPLE.TEST" };
    }

    private async Task AssertDuplicateAsync(Func<MotoHubDbContext, Task> action)
    {
        await using var context = fixture.CreateContext();
        await Assert.ThrowsAsync<DbUpdateException>(() => action(context));
    }

    private static void AssertUnique(IReadOnlyList<IndexMetadata> indexes, string table, string[] columns, string? expectedFilter = null)
    {
        var index = FindIndex(indexes, table, columns);
        Assert.True(index.IsUnique);
        if (expectedFilter is not null)
        {
            Assert.NotNull(index.FilterDefinition);
            Assert.Equal(NormalizeFilter(expectedFilter), NormalizeFilter(index.FilterDefinition!));
        }
        else
        {
            Assert.Null(index.FilterDefinition);
        }
    }

    private static string NormalizeFilter(string filter)
        => new string(filter
            .Replace("[", string.Empty, StringComparison.Ordinal)
            .Replace("]", string.Empty, StringComparison.Ordinal)
            .Replace("(", string.Empty, StringComparison.Ordinal)
            .Replace(")", string.Empty, StringComparison.Ordinal)
            .Where(character => !char.IsWhiteSpace(character))
            .ToArray())
            .ToUpperInvariant();

    private static void AssertPrimaryKey(IReadOnlyList<IndexMetadata> indexes, string table, string[] columns)
    {
        var index = FindIndex(indexes, table, columns);
        Assert.True(index.IsUnique);
        Assert.True(index.IsPrimaryKey);
    }

    private static IndexMetadata FindIndex(IReadOnlyList<IndexMetadata> indexes, string table, string[] columns)
    {
        var index = indexes
            .Where(x => x.TableName == table)
            .GroupBy(x => x.IndexName)
            .Select(group => group.OrderBy(x => x.KeyOrdinal).ToArray())
            .SingleOrDefault(group => group.Select(x => x.ColumnName).SequenceEqual(columns));
        Assert.NotNull(index);
        return index![0];
    }

    private static async Task<List<IndexMetadata>> ReadIndexesAsync(DbConnection connection, string[] tables)
    {
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT t.name, i.name, i.is_unique, i.is_primary_key, i.filter_definition, ic.key_ordinal, c.name
            FROM sys.tables AS t
            INNER JOIN sys.indexes AS i ON i.object_id = t.object_id
            INNER JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
            INNER JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE t.name IN (SELECT value FROM STRING_SPLIT(@tables, ',')) AND i.index_id > 0 AND ic.key_ordinal > 0
            ORDER BY t.name, i.name, ic.key_ordinal;
            """;
        var parameter = command.CreateParameter();
        parameter.ParameterName = "@tables";
        parameter.Value = string.Join(',', tables);
        command.Parameters.Add(parameter);
        var result = new List<IndexMetadata>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            result.Add(new IndexMetadata(reader.GetString(0), reader.GetString(1), reader.GetBoolean(2), reader.GetBoolean(3), reader.IsDBNull(4) ? null : reader.GetString(4), Convert.ToInt32(reader.GetValue(5)), reader.GetString(6)));
        }
        return result;
    }

    private sealed record IndexMetadata(string TableName, string IndexName, bool IsUnique, bool IsPrimaryKey, string? FilterDefinition, int KeyOrdinal, string ColumnName);
}
