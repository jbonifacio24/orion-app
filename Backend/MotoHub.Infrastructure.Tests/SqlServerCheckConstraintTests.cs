using System.Data.Common;
using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Tests.SqlServer;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

[Collection(SqlServerCollection.Name)]
[Trait("Category", "SqlServer")]
[Trait("Category", "Integration")]
public sealed class SqlServerCheckConstraintTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Critical_check_constraints_match_sql_server_metadata()
    {
        await using var context = fixture.CreateContext();
        var checks = await ReadChecksAsync(context.Database.GetDbConnection());

        AssertCheck(checks, "Motorcycles", "CK_Motorcycles_Year", "[Year] BETWEEN 1885 AND 2200");
        AssertCheck(checks, "Motorcycles", "CK_Motorcycles_Displacement", "[Displacement] IS NULL OR [Displacement] > 0");
        AssertCheck(checks, "Products", "CK_Products_Price", "[Price] IS NULL OR [Price] >= 0");
        AssertCheck(checks, "Products", "CK_Products_StockQuantity", "[StockQuantity] IS NULL OR [StockQuantity] >= 0");
        AssertCheck(checks, "ProductReviews", "CK_ProductReviews_Rating", "[Rating] BETWEEN 1 AND 5");
        AssertCheck(checks, "WorkshopReviews", "CK_WorkshopReviews_Rating", "[Rating] BETWEEN 1 AND 5");
        AssertCheck(checks, "Workshops", "CK_Workshops_Coordinates", "([Latitude] IS NULL OR [Latitude] >= -90 AND [Latitude] <= 90) AND ([Longitude] IS NULL OR [Longitude] >= -180 AND [Longitude] <= 180)");
        AssertCheck(checks, "TheftReports", "CK_TheftReports_Coordinates", "([Latitude] IS NULL OR [Latitude] >= -90 AND [Latitude] <= 90) AND ([Longitude] IS NULL OR [Longitude] >= -180 AND [Longitude] <= 180)");
        AssertCheck(checks, "WorkshopSchedules", "CK_WorkshopSchedules_DayOfWeek", "[DayOfWeek] BETWEEN 0 AND 6");
        AssertCheck(checks, "WorkshopSchedules", "CK_WorkshopSchedules_TimeRange", "[IsClosed] = 1 OR [OpenTime] IS NOT NULL AND [CloseTime] IS NOT NULL AND [CloseTime] > [OpenTime]");
        AssertCheck(checks, "Referrals", "CK_Referrals_NotSelf", "[ReferredUserId] IS NULL OR [ReferredUserId] <> [ReferrerUserId]");
        AssertCheck(checks, "ReferralRewards", "CK_ReferralRewards_Amount", "[Amount] IS NULL OR [Amount] >= 0");
        AssertCheck(checks, "Subscriptions", "CK_Subscriptions_Period", "[CurrentPeriodEnd] >= [CurrentPeriodStart]");
    }

    [Fact]
    public async Task Motorcycle_and_product_boundaries_are_enforced_by_sql_server()
    {
        var ownerId = await CreateUserAsync("check-motorcycle");
        await SaveMotorcycleAsync(ownerId, 1885, 1);
        await SaveMotorcycleAsync(ownerId, 2200, 2);
        await AssertRejectedAsync(async context => await AddMotorcycleAsync(context, ownerId, 1884, 1));
        await AssertRejectedAsync(async context => await AddMotorcycleAsync(context, ownerId, 2201, 1));
        await AssertRejectedAsync(async context => await AddMotorcycleAsync(context, ownerId, 2024, 0));

        var (productId, sellerId) = await CreateProductAsync("check-product");
        await UpdateProductAsync(productId, sellerId, 0, 0);
        await AssertRejectedAsync(async context => await UpdateProductAsync(context, productId, sellerId, -1, 0));
        await AssertRejectedAsync(async context => await UpdateProductAsync(context, productId, sellerId, 0, -1));
    }

    [Fact]
    public async Task Review_and_coordinate_boundaries_are_enforced_by_sql_server()
    {
        var (productId, _) = await CreateProductAsync("check-product-review");
        await SaveProductReviewAsync(productId, 1);
        await SaveProductReviewAsync(productId, 5);
        var invalidReviewAuthorId = await CreateUserAsync("check-product-rating-invalid");
        await AssertRejectedAsync(async context => await AddProductReviewAsync(context, productId, invalidReviewAuthorId, 0));
        await AssertRejectedAsync(async context => await AddProductReviewAsync(context, productId, invalidReviewAuthorId, 6));

        var workshopId = await CreateWorkshopAsync("check-workshop", 0, 0);
        var reviewAuthor = await CreateUserAsync("check-workshop-review");
        await SaveWorkshopReviewAsync(workshopId, reviewAuthor, 1);
        await SaveWorkshopReviewAsync(workshopId, await CreateUserAsync("check-workshop-rating-maximum"), 5);
        await AssertRejectedAsync(async context => await AddWorkshopReviewAsync(context, workshopId, await CreateUserAsync("check-workshop-rating-below-minimum"), 0));
        await AssertRejectedAsync(async context => await AddWorkshopReviewAsync(context, workshopId, await CreateUserAsync("check-workshop-invalid"), 6));

        await UpdateWorkshopCoordinatesAsync(workshopId, -90, 180);
        await AssertRejectedAsync(async context => await UpdateWorkshopCoordinatesAsync(context, workshopId, -91, 0));
        await AssertRejectedAsync(async context => await UpdateWorkshopCoordinatesAsync(context, workshopId, 0, 181));

        var theftReporter = await CreateUserAsync("check-theft");
        await SaveTheftReportAsync(theftReporter, 90, -180);
        await AssertRejectedAsync(async context => await AddTheftReportAsync(context, theftReporter, 91, 0));
    }

    [Fact]
    public async Task Schedule_referral_and_reward_constraints_are_enforced_by_sql_server()
    {
        var ownerId = await CreateUserAsync("check-schedule");
        var workshopId = await CreateWorkshopAsync("check-schedule-workshop", null, null);
        await SaveScheduleAsync(workshopId, 0, true, null, null);
        await SaveScheduleAsync(workshopId, 6, false, new TimeOnly(9, 0), new TimeOnly(17, 0));
        await AssertRejectedAsync(async context => await AddScheduleAsync(context, workshopId, -1, true, null, null));
        await AssertRejectedAsync(async context => await AddScheduleAsync(context, workshopId, 7, true, null, null));
        await AssertRejectedAsync(async context => await AddScheduleAsync(context, workshopId, 2, false, null, new TimeOnly(17, 0)));
        await AssertRejectedAsync(async context => await AddScheduleAsync(context, workshopId, 3, false, new TimeOnly(17, 0), new TimeOnly(9, 0)));

        var referredUserId = await CreateUserAsync("check-referred");
        await SaveReferralAsync(ownerId, referredUserId);
        await AssertRejectedAsync(async context => await AddReferralAsync(context, ownerId, ownerId));

        var referralId = await CreateReferralAsync(ownerId, referredUserId);
        var rewardUserId = await CreateUserAsync("check-reward");
        await SaveRewardAsync(referralId, rewardUserId, 0, RewardType.Credit);
        await AssertRejectedAsync(async context => await AddRewardAsync(context, referralId, rewardUserId, -1, RewardType.Discount));
    }

    [Fact]
    public async Task Subscription_period_constraint_is_enforced_by_sql_server()
    {
        var userId = await CreateUserAsync("check-subscription");
        var planId = await CreatePlanAsync();
        var start = DateTimeOffset.UtcNow;
        await SaveSubscriptionAsync(userId, planId, start, start.AddDays(1));
        await AssertRejectedAsync(async context => await AddSubscriptionAsync(context, userId, planId, start, start.AddDays(-1)));
    }

    [Fact]
    public void Check_definition_normalization_preserves_semantically_distinct_expressions()
    {
        Assert.NotEqual(NormalizeCheckDefinition("A AND B"), NormalizeCheckDefinition("A OR B"));
        Assert.NotEqual(NormalizeCheckDefinition("A >= 0"), NormalizeCheckDefinition("A > 0"));
        Assert.NotEqual(NormalizeCheckDefinition("A <= 5"), NormalizeCheckDefinition("A < 5"));
        Assert.NotEqual(NormalizeCheckDefinition("A <> B"), NormalizeCheckDefinition("A = B"));
        Assert.NotEqual(NormalizeCheckDefinition("NOT (A AND B)"), NormalizeCheckDefinition("NOT A AND B"));
        Assert.NotEqual(NormalizeCheckDefinition("X IN (1, 2, 3)"), NormalizeCheckDefinition("X IN 1, 2, 3"));
        Assert.NotEqual(NormalizeCheckDefinition("A AND (B OR C)"), NormalizeCheckDefinition("A AND B OR C"));
        Assert.NotEqual(NormalizeCheckDefinition("NOT (A BETWEEN 1 AND 5)"), NormalizeCheckDefinition("NOT A >= 1 AND A <= 5"));
    }

    private async Task<Guid> CreateUserAsync(string prefix)
    {
        await using var context = fixture.CreateContext();
        var suffix = Guid.NewGuid().ToString("N");
        var user = new User { UserName = $"{prefix}-{suffix}", NormalizedUserName = $"{prefix}-{suffix}".ToUpperInvariant(), Email = $"{prefix}-{suffix}@example.test", NormalizedEmail = $"{prefix}-{suffix}@EXAMPLE.TEST" };
        context.Users.Add(user);
        await context.SaveChangesAsync();
        return user.Id;
    }

    private async Task SaveMotorcycleAsync(Guid ownerId, int year, int displacement)
    {
        await using var context = fixture.CreateContext();
        await AddMotorcycleAsync(context, ownerId, year, displacement);
        await context.SaveChangesAsync();
    }

    private static Task AddMotorcycleAsync(MotoHubDbContext context, Guid ownerId, int year, int displacement)
    {
        context.Motorcycles.Add(new Motorcycle { OwnerUserId = ownerId, Brand = "B", Model = Guid.NewGuid().ToString("N"), Year = year, Displacement = displacement });
        return Task.CompletedTask;
    }

    private async Task<(Guid ProductId, Guid SellerId)> CreateProductAsync(string prefix)
    {
        await using var context = fixture.CreateContext();
        var seller = new User { UserName = $"{prefix}-{Guid.NewGuid():N}", NormalizedUserName = $"{prefix}-{Guid.NewGuid():N}".ToUpperInvariant(), Email = $"{prefix}-{Guid.NewGuid():N}@example.test", NormalizedEmail = $"{prefix}-{Guid.NewGuid():N}@EXAMPLE.TEST" };
        var category = new ProductCategory { Name = $"Category {Guid.NewGuid():N}", Slug = $"category-{Guid.NewGuid():N}" };
        var product = new Product { Seller = seller, Category = category, Name = $"Product {Guid.NewGuid():N}", Description = "Check test product", Condition = ProductCondition.New, Status = ProductStatus.Draft };
        context.Products.Add(product);
        await context.SaveChangesAsync();
        return (product.Id, seller.Id);
    }

    private async Task UpdateProductAsync(Guid productId, Guid sellerId, decimal? price, int? stock)
    {
        await using var context = fixture.CreateContext();
        await UpdateProductAsync(context, productId, sellerId, price, stock);
        await context.SaveChangesAsync();
    }

    private static async Task UpdateProductAsync(MotoHubDbContext context, Guid productId, Guid sellerId, decimal? price, int? stock)
    {
        var product = await context.Products.IgnoreQueryFilters().SingleAsync(x => x.Id == productId);
        product.Price = price;
        product.StockQuantity = stock;
        product.SellerUserId = sellerId;
    }

    private async Task SaveProductReviewAsync(Guid productId, int rating)
    {
        var authorId = await CreateUserAsync("check-product-rating");
        await using var context = fixture.CreateContext();
        await AddProductReviewAsync(context, productId, authorId, rating);
        await context.SaveChangesAsync();
    }

    private static Task AddProductReviewAsync(MotoHubDbContext context, Guid productId, Guid authorId, int rating)
    {
        context.ProductReviews.Add(new ProductReview { ProductId = productId, AuthorUserId = authorId, Rating = rating, Status = ReviewStatus.Published });
        return Task.CompletedTask;
    }

    private async Task SaveWorkshopReviewAsync(Guid workshopId, Guid authorId, int rating)
    {
        await using var context = fixture.CreateContext();
        await AddWorkshopReviewAsync(context, workshopId, authorId, rating);
        await context.SaveChangesAsync();
    }

    private static Task AddWorkshopReviewAsync(MotoHubDbContext context, Guid workshopId, Guid authorId, int rating)
    {
        context.WorkshopReviews.Add(new WorkshopReview { WorkshopId = workshopId, AuthorUserId = authorId, Rating = rating, Status = ReviewStatus.Published });
        return Task.CompletedTask;
    }

    private async Task<Guid> CreateWorkshopAsync(string name, decimal? latitude, decimal? longitude)
    {
        var ownerId = await CreateUserAsync(name);
        await using var context = fixture.CreateContext();
        var workshop = new Workshop { OwnerUserId = ownerId, Name = $"Workshop {Guid.NewGuid():N}", Status = WorkshopStatus.Active, Latitude = latitude, Longitude = longitude };
        context.Workshops.Add(workshop);
        await context.SaveChangesAsync();
        return workshop.Id;
    }

    private async Task UpdateWorkshopCoordinatesAsync(Guid workshopId, decimal? latitude, decimal? longitude)
    {
        await using var context = fixture.CreateContext();
        await UpdateWorkshopCoordinatesAsync(context, workshopId, latitude, longitude);
        await context.SaveChangesAsync();
    }

    private static async Task UpdateWorkshopCoordinatesAsync(MotoHubDbContext context, Guid workshopId, decimal? latitude, decimal? longitude)
    {
        var workshop = await context.Workshops.IgnoreQueryFilters().SingleAsync(x => x.Id == workshopId);
        workshop.Latitude = latitude;
        workshop.Longitude = longitude;
    }

    private async Task SaveTheftReportAsync(Guid reporterId, decimal latitude, decimal longitude)
    {
        await using var context = fixture.CreateContext();
        await AddTheftReportAsync(context, reporterId, latitude, longitude);
        await context.SaveChangesAsync();
    }

    private static Task AddTheftReportAsync(MotoHubDbContext context, Guid reporterId, decimal latitude, decimal longitude)
    {
        context.TheftReports.Add(new TheftReport { ReporterUserId = reporterId, Title = "Theft", Description = "Check test report", TheftDate = DateTimeOffset.UtcNow, Status = TheftReportStatus.Reported, Latitude = latitude, Longitude = longitude });
        return Task.CompletedTask;
    }

    private async Task SaveScheduleAsync(Guid workshopId, int day, bool isClosed, TimeOnly? open, TimeOnly? close)
    {
        await using var context = fixture.CreateContext();
        await AddScheduleAsync(context, workshopId, day, isClosed, open, close);
        await context.SaveChangesAsync();
    }

    private static Task AddScheduleAsync(MotoHubDbContext context, Guid workshopId, int day, bool isClosed, TimeOnly? open, TimeOnly? close)
    {
        context.WorkshopSchedules.Add(new WorkshopSchedule { WorkshopId = workshopId, DayOfWeek = day, IsClosed = isClosed, OpenTime = open, CloseTime = close });
        return Task.CompletedTask;
    }

    private async Task SaveReferralAsync(Guid referrerId, Guid referredId)
    {
        await using var context = fixture.CreateContext();
        await AddReferralAsync(context, referrerId, referredId);
        await context.SaveChangesAsync();
    }

    private async Task<Guid> CreateReferralAsync(Guid referrerId, Guid referredId)
    {
        await using var context = fixture.CreateContext();
        var referral = new Referral { ReferrerUserId = referrerId, ReferredUserId = referredId, Code = $"ref-{Guid.NewGuid():N}", Status = ReferralStatus.Accepted };
        context.Referrals.Add(referral);
        await context.SaveChangesAsync();
        return referral.Id;
    }

    private static Task AddReferralAsync(MotoHubDbContext context, Guid referrerId, Guid referredId)
    {
        context.Referrals.Add(new Referral { ReferrerUserId = referrerId, ReferredUserId = referredId, Code = $"ref-{Guid.NewGuid():N}", Status = ReferralStatus.Pending });
        return Task.CompletedTask;
    }

    private async Task SaveRewardAsync(Guid referralId, Guid userId, decimal amount, RewardType rewardType)
    {
        await using var context = fixture.CreateContext();
        await AddRewardAsync(context, referralId, userId, amount, rewardType);
        await context.SaveChangesAsync();
    }

    private static Task AddRewardAsync(MotoHubDbContext context, Guid referralId, Guid userId, decimal amount, RewardType rewardType)
    {
        context.ReferralRewards.Add(new ReferralReward { ReferralId = referralId, UserId = userId, RewardType = rewardType, Amount = amount, Status = RewardStatus.Pending });
        return Task.CompletedTask;
    }

    private async Task<Guid> CreatePlanAsync()
    {
        await using var context = fixture.CreateContext();
        var plan = new SubscriptionPlan { Code = $"plan-{Guid.NewGuid():N}", Name = "Check plan", Price = 10, Currency = "EUR" };
        context.SubscriptionPlans.Add(plan);
        await context.SaveChangesAsync();
        return plan.Id;
    }

    private async Task SaveSubscriptionAsync(Guid userId, Guid planId, DateTimeOffset start, DateTimeOffset end)
    {
        await using var context = fixture.CreateContext();
        await AddSubscriptionAsync(context, userId, planId, start, end);
        await context.SaveChangesAsync();
    }

    private static Task AddSubscriptionAsync(MotoHubDbContext context, Guid userId, Guid planId, DateTimeOffset start, DateTimeOffset end)
    {
        context.Subscriptions.Add(new Subscription { UserId = userId, SubscriptionPlanId = planId, Status = SubscriptionStatus.Active, Provider = SubscriptionProvider.Stripe, ProviderSubscriptionId = $"provider-{Guid.NewGuid():N}", StartedAt = start, CurrentPeriodStart = start, CurrentPeriodEnd = end });
        return Task.CompletedTask;
    }

    private async Task AssertRejectedAsync(Func<MotoHubDbContext, Task> action)
    {
        await using var context = fixture.CreateContext();
        await Assert.ThrowsAsync<DbUpdateException>(async () =>
        {
            await action(context);
            await context.SaveChangesAsync();
        });
    }

    private static void AssertCheck(IReadOnlyList<CheckMetadata> checks, string table, string name, string expectedDefinition)
    {
        var check = checks.SingleOrDefault(x => x.TableName == table && x.ConstraintName == name);
        Assert.NotNull(check);
        Assert.False(check!.IsDisabled);
        Assert.False(check.IsNotTrusted);
        Assert.Equal(NormalizeCheckDefinition(expectedDefinition), NormalizeCheckDefinition(check.Definition));
    }

    private static string NormalizeCheckDefinition(string definition)
    {
        var normalized = definition.Replace("[", string.Empty, StringComparison.Ordinal).Replace("]", string.Empty, StringComparison.Ordinal);
        normalized = Regex.Replace(
            normalized,
            @"(?<column>[A-Za-z_][A-Za-z0-9_]*)\s+BETWEEN\s+(?<lower>-?\d+(?:\.\d+)?)\s+AND\s+(?<upper>-?\d+(?:\.\d+)?)",
            "(${column} >= ${lower} AND ${column} <= ${upper})",
            RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);
        normalized = Regex.Replace(normalized, @"\((-?\d+(?:\.\d+)?)\)", "$1", RegexOptions.CultureInvariant);
        normalized = RemoveOuterParentheses(normalized.Trim());
        return new string(normalized.Where(c => !char.IsWhiteSpace(c)).ToArray()).ToUpperInvariant();
    }

    private static string RemoveOuterParentheses(string definition)
    {
        while (definition.StartsWith('(') && definition.EndsWith(')'))
        {
            var depth = 0;
            var enclosesWholeExpression = true;

            for (var index = 0; index < definition.Length; index++)
            {
                depth += definition[index] == '(' ? 1 : definition[index] == ')' ? -1 : 0;
                if (depth == 0 && index < definition.Length - 1)
                {
                    enclosesWholeExpression = false;
                    break;
                }
            }

            if (!enclosesWholeExpression)
            {
                break;
            }

            definition = definition[1..^1].Trim();
        }

        return definition;
    }

    private static async Task<List<CheckMetadata>> ReadChecksAsync(DbConnection connection)
    {
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT cc.name, t.name, cc.definition, cc.is_disabled, cc.is_not_trusted
            FROM sys.check_constraints AS cc
            INNER JOIN sys.tables AS t ON t.object_id = cc.parent_object_id
            INNER JOIN sys.schemas AS s ON s.schema_id = t.schema_id
            WHERE s.name = N'dbo'
            ORDER BY t.name, cc.name;
            """;
        var result = new List<CheckMetadata>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            result.Add(new CheckMetadata(reader.GetString(0), reader.GetString(1), reader.GetString(2), reader.GetBoolean(3), reader.GetBoolean(4)));
        }
        return result;
    }

    private sealed record CheckMetadata(string ConstraintName, string TableName, string Definition, bool IsDisabled, bool IsNotTrusted);
}
