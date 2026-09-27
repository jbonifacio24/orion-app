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
public sealed class SqlServerForeignKeyTests(SqlServerTestFixture fixture)
{
    [Fact]
    public async Task Critical_foreign_keys_and_delete_actions_exist_in_sql_server()
    {
        await using var context = fixture.CreateContext();
        var foreignKeys = await ReadForeignKeysAsync(context.Database.GetDbConnection());

        AssertForeignKey(foreignKeys, "Products", ["SellerUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Products", ["CategoryId"], "ProductCategories", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Motorcycles", ["OwnerUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "ProductImages", ["ProductId"], "Products", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "MotorcycleImages", ["MotorcycleId"], "Motorcycles", ["Id"], "CASCADE");

        AssertForeignKey(foreignKeys, "ProductFavorites", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "ProductFavorites", ["ProductId"], "Products", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "MotorcycleFavorites", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "MotorcycleFavorites", ["MotorcycleId"], "Motorcycles", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "WorkshopFavorites", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "WorkshopFavorites", ["WorkshopId"], "Workshops", ["Id"], "CASCADE");

        AssertForeignKey(foreignKeys, "ConversationParticipants", ["ConversationId"], "Conversations", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "ConversationParticipants", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Messages", ["ConversationId"], "Conversations", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "Messages", ["SenderUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Messages", ["ReplyToMessageId"], "Messages", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "MessageAttachments", ["MessageId"], "Messages", ["Id"], "CASCADE");

        AssertForeignKey(foreignKeys, "ModerationReports", ["ReporterUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "ModerationReports", ["ResolvedByUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "UserReports", ["ReportedUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "PostReports", ["PostId"], "Posts", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "CommentReports", ["PostCommentId"], "PostComments", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "ProductReports", ["ProductId"], "Products", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "MessageReports", ["MessageId"], "Messages", ["Id"], "NO_ACTION");

        AssertForeignKey(foreignKeys, "TheftReports", ["ReporterUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "TheftReports", ["MotorcycleId"], "Motorcycles", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "TheftAlertRecipients", ["TheftReportId"], "TheftReports", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "TheftAlertRecipients", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Notifications", ["RecipientUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "Notifications", ["ActorUserId"], "Users", ["Id"], "NO_ACTION");

        AssertForeignKey(foreignKeys, "Posts", ["AuthorUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "PostMedia", ["PostId"], "Posts", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "PostComments", ["PostId"], "Posts", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "PostComments", ["AuthorUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "PostComments", ["ParentCommentId"], "PostComments", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "PostLikes", ["PostId"], "Posts", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "PostLikes", ["UserId"], "Users", ["Id"], "NO_ACTION");

        AssertForeignKey(foreignKeys, "News", ["AuthorUserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "NewsCategoryAssignments", ["NewsId"], "News", ["Id"], "CASCADE");
        AssertForeignKey(foreignKeys, "NewsCategoryAssignments", ["NewsCategoryId"], "NewsCategories", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "RefreshTokens", ["UserId"], "Users", ["Id"], "NO_ACTION");
        AssertForeignKey(foreignKeys, "RefreshTokens", ["ReplacedByTokenId"], "RefreshTokens", ["Id"], "NO_ACTION");
    }

    [Fact]
    public async Task Product_image_delete_is_cascaded_by_sql_server()
    {
        var (_, productId, imageId) = await CreateProductWithImageAsync();

        await using (var deleteContext = fixture.CreateContext())
        {
            var product = await deleteContext.Products.IgnoreQueryFilters().SingleAsync(x => x.Id == productId);
            deleteContext.Products.Remove(product);
            await deleteContext.SaveChangesAsync();
        }

        await using var verificationContext = fixture.CreateContext();
        Assert.Null(await verificationContext.ProductImages.IgnoreQueryFilters().SingleOrDefaultAsync(x => x.Id == imageId));
    }

    [Fact]
    public async Task User_delete_is_rejected_by_product_foreign_key()
    {
        var (userId, _, _) = await CreateProductWithImageAsync();

        await using var deleteContext = fixture.CreateContext();
        var user = await deleteContext.Users.IgnoreQueryFilters().SingleAsync(x => x.Id == userId);
        deleteContext.Users.Remove(user);
        await Assert.ThrowsAsync<DbUpdateException>(() => deleteContext.SaveChangesAsync());
    }

    private async Task<(Guid UserId, Guid ProductId, Guid ImageId)> CreateProductWithImageAsync()
    {
        await using var context = fixture.CreateContext();
        var user = NewUser();
        var category = new ProductCategory
        {
            Name = $"Category {Guid.NewGuid():N}",
            Slug = $"category-{Guid.NewGuid():N}"
        };
        var product = new Product
        {
            Seller = user,
            Category = category,
            Name = $"Product {Guid.NewGuid():N}",
            Description = "SQL Server foreign key test product",
            Condition = ProductCondition.New,
            Status = ProductStatus.Draft
        };
        var image = new ProductImage
        {
            Product = product,
            StorageKey = Guid.NewGuid().ToString("N"),
            Url = "https://example.test/foreign-key-image"
        };
        context.ProductImages.Add(image);
        await context.SaveChangesAsync();
        return (user.Id, product.Id, image.Id);
    }

    private static User NewUser()
    {
        var suffix = Guid.NewGuid().ToString("N");
        return new User
        {
            UserName = $"fk-user-{suffix}",
            NormalizedUserName = $"FK-USER-{suffix}",
            Email = $"fk-user-{suffix}@example.test",
            NormalizedEmail = $"FK-USER-{suffix}@EXAMPLE.TEST"
        };
    }

    private static void AssertForeignKey(
        IReadOnlyList<ForeignKeyMetadata> foreignKeys,
        string childTable,
        string[] childColumns,
        string parentTable,
        string[] parentColumns,
        string deleteAction)
    {
        Assert.Single(childColumns);
        Assert.Single(parentColumns);
        var matches = foreignKeys.Where(x =>
            x.ChildTable == childTable &&
            x.ParentTable == parentTable &&
            x.DeleteAction == deleteAction &&
            x.ChildColumn == childColumns[0] &&
            x.ParentColumn == parentColumns[0]).ToArray();
        Assert.Single(matches);
    }

    private static async Task<List<ForeignKeyMetadata>> ReadForeignKeysAsync(DbConnection connection)
    {
        await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = """
            SELECT fk.name, childTable.name, childColumn.name, parentTable.name, parentColumn.name,
                   fk.delete_referential_action_desc, fkc.constraint_column_id
            FROM sys.foreign_keys AS fk
            INNER JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = fk.object_id
            INNER JOIN sys.tables AS childTable ON childTable.object_id = fk.parent_object_id
            INNER JOIN sys.columns AS childColumn ON childColumn.object_id = fkc.parent_object_id
                AND childColumn.column_id = fkc.parent_column_id
            INNER JOIN sys.tables AS parentTable ON parentTable.object_id = fk.referenced_object_id
            INNER JOIN sys.columns AS parentColumn ON parentColumn.object_id = fkc.referenced_object_id
                AND parentColumn.column_id = fkc.referenced_column_id
            ORDER BY fk.name, fkc.constraint_column_id;
            """;
        var result = new List<ForeignKeyMetadata>();
        await using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            result.Add(new ForeignKeyMetadata(
                reader.GetString(0),
                reader.GetString(1),
                reader.GetString(2),
                reader.GetString(3),
                reader.GetString(4),
                reader.GetString(5),
                Convert.ToInt32(reader.GetValue(6))));
        }

        return result;
    }

    private sealed record ForeignKeyMetadata(
        string ForeignKeyName,
        string ChildTable,
        string ChildColumn,
        string ParentTable,
        string ParentColumn,
        string DeleteAction,
        int Ordinal)
    {
    }
}
