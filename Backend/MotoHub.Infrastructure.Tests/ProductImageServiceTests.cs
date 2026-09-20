using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Storage;
using MotoHub.Domain;
using MotoHub.Infrastructure.Marketplace;
using MotoHub.Infrastructure.Persistence;
using MotoHub.Infrastructure.Storage;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class ProductImageServiceTests
{
    [Fact]
    public async Task First_upload_is_primary_order_zero_and_has_no_thumbnail()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        await context.SaveChangesAsync();
        var storage = new FakeStorage();

        var result = await CreateService(context, storage).UploadAsync(owner.Id, product.Id, Request(), default);

        Assert.Equal(0, result.DisplayOrder);
        Assert.True(result.IsPrimary);
        Assert.Null(result.ThumbnailUrl);
        var persisted = await context.ProductImages.SingleAsync();
        Assert.Equal(product.Id, persisted.ProductId);
        Assert.Equal(1, storage.SaveCalls);
    }

    [Fact]
    public async Task Second_upload_appends_and_does_not_replace_primary()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        product.Images.Add(new ProductImage { StorageKey = "one.jpg", Url = "/one.jpg", DisplayOrder = 0, IsPrimary = true });
        await context.SaveChangesAsync();

        var result = await CreateService(context, new FakeStorage()).UploadAsync(owner.Id, product.Id, Request(), default);

        Assert.Equal(1, result.DisplayOrder);
        Assert.False(result.IsPrimary);
        Assert.True((await context.ProductImages.SingleAsync(x => x.DisplayOrder == 0)).IsPrimary);
    }

    [Fact]
    public async Task Upload_rejects_foreign_and_deleted_products()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var other = AddUser(context, "other");
        var foreign = AddProduct(context, other.Id);
        var deleted = AddProduct(context, owner.Id);
        deleted.IsDeleted = true;
        await context.SaveChangesAsync();
        var service = CreateService(context, new FakeStorage());

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UploadAsync(owner.Id, foreign.Id, Request(), default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UploadAsync(owner.Id, deleted.Id, Request(), default));
    }

    [Fact]
    public async Task Eleventh_upload_is_rejected_without_storage_save()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        for (var index = 0; index < 10; index++)
            product.Images.Add(new ProductImage { StorageKey = $"{index}.jpg", Url = $"/{index}.jpg", DisplayOrder = index, IsPrimary = index == 0 });
        await context.SaveChangesAsync();
        var storage = new FakeStorage();

        await Assert.ThrowsAsync<ConflictException>(() => CreateService(context, storage).UploadAsync(owner.Id, product.Id, Request(), default));

        Assert.Equal(0, storage.SaveCalls);
        Assert.Equal(10, await context.ProductImages.CountAsync());
    }

    [Fact]
    public async Task Storage_failure_does_not_persist_image()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        await context.SaveChangesAsync();
        var storage = new FakeStorage { SaveException = new IOException("disk failure") };

        await Assert.ThrowsAsync<IOException>(() => CreateService(context, storage).UploadAsync(owner.Id, product.Id, Request(), default));

        Assert.Empty(await context.ProductImages.ToListAsync());
    }

    [Fact]
    public async Task Database_failure_after_storage_save_compensates_file_and_preserves_original_error()
    {
        var databaseName = Guid.NewGuid().ToString();
        await using (var seedContext = CreateContext(databaseName))
        {
            var owner = AddUser(seedContext, "owner");
            AddProduct(seedContext, owner.Id);
            await seedContext.SaveChangesAsync();
        }

        await using var context = CreateThrowingContext(databaseName);
        var product = await context.Products.IgnoreQueryFilters().SingleAsync();
        var storage = new FakeStorage();

        await Assert.ThrowsAsync<InvalidOperationException>(() => CreateService(context, storage).UploadAsync(product.SellerUserId, product.Id, Request(), default));

        Assert.Equal(1, storage.DeleteCalls);
        Assert.Equal(storage.LastSaved!.StorageKey, storage.LastDeletedKey);
    }

    [Fact]
    public async Task Cleanup_failure_does_not_hide_database_failure()
    {
        var databaseName = Guid.NewGuid().ToString();
        await using (var seedContext = CreateContext(databaseName))
        {
            var owner = AddUser(seedContext, "owner");
            AddProduct(seedContext, owner.Id);
            await seedContext.SaveChangesAsync();
        }

        await using var context = CreateThrowingContext(databaseName);
        var product = await context.Products.IgnoreQueryFilters().SingleAsync();
        var storage = new FakeStorage { DeleteException = new IOException("cleanup failure") };

        var exception = await Assert.ThrowsAsync<InvalidOperationException>(() => CreateService(context, storage).UploadAsync(product.SellerUserId, product.Id, Request(), default));

        Assert.Equal("database failure", exception.Message);
        Assert.Equal(1, storage.DeleteCalls);
    }

    [Fact]
    public async Task Delete_non_primary_normalizes_order_and_cleans_storage()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        var image0 = new ProductImage { StorageKey = "zero.jpg", Url = "/zero.jpg", DisplayOrder = 0, IsPrimary = true };
        var image1 = new ProductImage { StorageKey = "one.jpg", Url = "/one.jpg", DisplayOrder = 1, IsPrimary = false };
        var image2 = new ProductImage { StorageKey = "two.jpg", Url = "/two.jpg", DisplayOrder = 2, IsPrimary = false };
        product.Images.Add(image0); product.Images.Add(image1); product.Images.Add(image2);
        await context.SaveChangesAsync();
        var storage = new FakeStorage();

        await CreateService(context, storage).DeleteAsync(owner.Id, product.Id, image1.Id, default);

        var remaining = await context.ProductImages.OrderBy(x => x.DisplayOrder).ToListAsync();
        Assert.Equal([0, 1], remaining.Select(x => x.DisplayOrder));
        Assert.Equal(image0.Id, remaining[0].Id);
        Assert.Equal("one.jpg", storage.LastDeletedKey);
    }

    [Fact]
    public async Task Delete_primary_selects_deterministic_replacement()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        var primary = new ProductImage { StorageKey = "primary.jpg", Url = "/primary.jpg", DisplayOrder = 0, IsPrimary = true };
        var first = new ProductImage { StorageKey = "first.jpg", Url = "/first.jpg", DisplayOrder = 1, IsPrimary = false };
        var second = new ProductImage { StorageKey = "second.jpg", Url = "/second.jpg", DisplayOrder = 2, IsPrimary = false };
        product.Images.Add(primary); product.Images.Add(first); product.Images.Add(second);
        await context.SaveChangesAsync();

        await CreateService(context, new FakeStorage()).DeleteAsync(owner.Id, product.Id, primary.Id, default);

        var remaining = await context.ProductImages.ToListAsync();
        Assert.Equal(first.Id, remaining.Single(x => x.IsPrimary).Id);
        Assert.Equal(1, remaining.Count(x => x.IsPrimary));
    }

    [Fact]
    public async Task Delete_last_image_leaves_no_primary_and_storage_failure_does_not_resurrect_row()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        var image = new ProductImage { StorageKey = "only.jpg", Url = "/only.jpg", DisplayOrder = 0, IsPrimary = true };
        product.Images.Add(image);
        await context.SaveChangesAsync();
        var storage = new FakeStorage { DeleteException = new IOException("disk failure") };

        await CreateService(context, storage).DeleteAsync(owner.Id, product.Id, image.Id, default);

        Assert.Empty(await context.ProductImages.ToListAsync());
        Assert.Equal(1, storage.DeleteCalls);
    }

    [Fact]
    public async Task Set_primary_changes_primary_and_is_idempotent()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var product = AddProduct(context, owner.Id);
        var first = new ProductImage { StorageKey = "first.jpg", Url = "/first.jpg", DisplayOrder = 0, IsPrimary = true };
        var second = new ProductImage { StorageKey = "second.jpg", Url = "/second.jpg", DisplayOrder = 1, IsPrimary = false };
        product.Images.Add(first); product.Images.Add(second);
        await context.SaveChangesAsync();
        var service = CreateService(context, new FakeStorage());

        var result = await service.SetPrimaryAsync(owner.Id, product.Id, second.Id, default);
        var repeated = await service.SetPrimaryAsync(owner.Id, product.Id, second.Id, default);

        Assert.Equal(second.Id, result.Id);
        Assert.Equal(second.Id, repeated.Id);
        Assert.False((await context.ProductImages.SingleAsync(x => x.Id == first.Id)).IsPrimary);
        Assert.True((await context.ProductImages.SingleAsync(x => x.Id == second.Id)).IsPrimary);
        Assert.Equal(1, await context.ProductImages.CountAsync(x => x.IsPrimary));
    }

    [Fact]
    public async Task Delete_and_set_primary_reject_image_from_different_product()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var productA = AddProduct(context, owner.Id);
        var productB = AddProduct(context, owner.Id);
        var imageB = new ProductImage { StorageKey = "b.jpg", Url = "/b.jpg", DisplayOrder = 0, IsPrimary = true };
        productB.Images.Add(imageB);
        await context.SaveChangesAsync();
        var service = CreateService(context, new FakeStorage());

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.DeleteAsync(owner.Id, productA.Id, imageB.Id, default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.SetPrimaryAsync(owner.Id, productA.Id, imageB.Id, default));
        Assert.True((await context.ProductImages.SingleAsync()).IsPrimary);
    }

    [Fact]
    public void Response_dto_does_not_expose_storage_key()
    {
        var properties = typeof(ProductImageResponseDto).GetProperties().Select(x => x.Name).ToArray();

        Assert.Equal(["Id", "Url", "ThumbnailUrl", "DisplayOrder", "IsPrimary"], properties);
        Assert.DoesNotContain("StorageKey", properties);
    }

    private static ProductImageService CreateService(MotoHubDbContext context, FakeStorage storage)
        => new(context, storage, new ImageFileValidator(Options.Create(new ProductImageStorageOptions())), Options.Create(new ProductImageStorageOptions()), NullLogger<ProductImageService>.Instance);

    private static UploadProductImageRequest Request()
        => new(new MemoryStream([0xFF, 0xD8, 0xFF, 0x00]), "upload.jpg", "image/jpeg", 4);

    private static Product AddProduct(MotoHubDbContext context, Guid ownerId)
    {
        var product = new Product { SellerUserId = ownerId, CategoryId = Guid.NewGuid(), Name = "Part", Description = "Description", Status = ProductStatus.Active };
        context.Products.Add(product);
        return product;
    }

    private static User AddUser(MotoHubDbContext context, string name)
    {
        var user = new User(Guid.NewGuid()) { UserName = name, NormalizedUserName = name.ToUpperInvariant(), Email = $"{name}@example.com", NormalizedEmail = $"{name.ToUpperInvariant()}@EXAMPLE.COM" };
        context.Users.Add(user);
        return user;
    }

    private static MotoHubDbContext CreateContext(string? databaseName = null)
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(databaseName ?? Guid.NewGuid().ToString())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;
        return new MotoHubDbContext(options);
    }

    private static MotoHubDbContext CreateThrowingContext(string databaseName)
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>()
            .UseInMemoryDatabase(databaseName)
            .AddInterceptors(new ThrowingSaveChangesInterceptor())
            .ConfigureWarnings(warnings => warnings.Ignore(InMemoryEventId.TransactionIgnoredWarning))
            .Options;
        return new MotoHubDbContext(options);
    }

    private sealed class ThrowingSaveChangesInterceptor : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
            => ValueTask.FromException<InterceptionResult<int>>(new InvalidOperationException("database failure"));
    }

    private sealed class FakeStorage : IProductImageStorage
    {
        public int SaveCalls { get; private set; }
        public int DeleteCalls { get; private set; }
        public Exception? SaveException { get; init; }
        public Exception? DeleteException { get; init; }
        public StoredProductImage? LastSaved { get; private set; }
        public string? LastDeletedKey { get; private set; }

        public Task<StoredProductImage> SaveAsync(Guid productId, Stream content, string extension, CancellationToken cancellationToken)
        {
            SaveCalls++;
            if (SaveException is not null) throw SaveException;
            LastSaved = new StoredProductImage($"products/{productId:N}/generated{extension}", $"/media/products/{productId:N}/generated{extension}");
            return Task.FromResult(LastSaved);
        }

        public Task DeleteAsync(string storageKey, CancellationToken cancellationToken)
        {
            DeleteCalls++;
            LastDeletedKey = storageKey;
            if (DeleteException is not null) throw DeleteException;
            return Task.CompletedTask;
        }
    }
}