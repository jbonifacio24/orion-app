using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Marketplace;
using MotoHub.Infrastructure.Persistence;
using Xunit;

namespace MotoHub.Infrastructure.Tests;

public sealed class MarketplaceServiceTests
{
    [Fact]
    public async Task Product_list_filters_search_category_status_and_paginates()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "seller");
        var category = AddCategory(context, "parts", "Repuestos", active: true, order: 2);
        var inactive = AddCategory(context, "inactive", "Inactive", active: false, order: 3);
        await context.SaveChangesAsync();
        var service = new ProductService(context);
        await service.CreateAsync(owner.Id, Request(category.Id, " Brake lever ", "Useful part", 20m), default);
        await service.CreateAsync(owner.Id, Request(category.Id, "Helmet", "Safety equipment", 80m), default);
        var hidden = await service.CreateAsync(owner.Id, Request(category.Id, "Hidden", "No", 5m), default);
        await service.DeleteAsync(owner.Id, hidden.Id, default);
        context.Products.Add(new Product { SellerUserId = owner.Id, CategoryId = inactive.Id, Name = "Inactive category", Description = "Hidden", Status = ProductStatus.Active });
        await context.SaveChangesAsync();

        var result = await service.GetActiveAsync(new ProductListQueryDto(Search: "part", Page: 1, PageSize: 1), owner.Id, default);

        Assert.Single(result.Items);
        Assert.Equal(1, result.TotalCount);
        Assert.Equal(1, result.TotalPages);
        Assert.Equal("Brake lever", result.Items.Single().Name);

        var paged = await service.GetActiveAsync(new ProductListQueryDto(Page: 1, PageSize: 1), owner.Id, default);
        Assert.Equal(2, paged.TotalCount);
        Assert.Equal(2, paged.TotalPages);
    }

    [Fact]
    public async Task Product_create_sets_ownership_status_publication_and_normalizes_currency()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "seller");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        await context.SaveChangesAsync();
        var product = await new ProductService(context).CreateAsync(owner.Id, Request(category.Id, " Product ", " Description ", 10.50m, "pen"), default);

        Assert.Equal(owner.Id, (await context.Products.SingleAsync()).SellerUserId);
        Assert.Equal(ProductStatus.Active, product.Status);
        Assert.NotNull(product.PublishedAt);
        Assert.Equal("PEN", product.Currency);
    }

    [Fact]
    public async Task Product_detail_projects_images_favorite_owner_and_private_data_is_not_in_response()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "seller", "Ana", "Rider", "private@example.com");
        var viewer = AddUser(context, "viewer");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        var product = new Product { SellerUserId = owner.Id, CategoryId = category.Id, Name = "Part", Description = "Description", Status = ProductStatus.Active, Images = { new ProductImage { Url = "https://image/full.jpg", ThumbnailUrl = "https://image/thumb.jpg", StorageKey = "private-key", DisplayOrder = 0, IsPrimary = true } } };
        context.Users.AddRange(owner, viewer);
        context.ProductCategories.Add(category);
        context.Products.Add(product);
        context.ProductFavorites.Add(new ProductFavorite { UserId = viewer.Id, ProductId = product.Id });
        await context.SaveChangesAsync();

        var result = await new ProductService(context).GetByIdAsync(viewer.Id, product.Id, default);

        Assert.True(result.IsFavorite);
        Assert.True(result.IsOwner == false);
        Assert.Equal("Ana Rider", result.Seller.DisplayName);
        Assert.DoesNotContain("private@example.com", result.Seller.ToString());
        Assert.Equal("https://image/full.jpg", result.Images.Single().Url);
        Assert.Equal(Convert.ToBase64String(product.RowVersion), result.RowVersion);
    }

    [Fact]
    public async Task Foreign_update_and_delete_return_not_found_and_delete_is_soft()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var other = AddUser(context, "other");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        await context.SaveChangesAsync();
        var service = new ProductService(context);
        var product = await service.CreateAsync(owner.Id, Request(category.Id, "Part", "Description", null), default);

        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.UpdateAsync(other.Id, product.Id, new UpdateProductRequestDto(category.Id, "Changed", "Description", null, null, null, ProductCondition.Used, null, product.RowVersion), default));
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.DeleteAsync(other.Id, product.Id, default));
        await service.DeleteAsync(owner.Id, product.Id, default);

        var deleted = await context.Products.IgnoreQueryFilters().SingleAsync(x => x.Id == product.Id);
        Assert.True(deleted.IsDeleted);
        Assert.NotNull(deleted.DeletedAt);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetByIdAsync(owner.Id, product.Id, default));
    }

    [Fact]
    public async Task Product_validation_rejects_invalid_values_and_inactive_category()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var category = AddCategory(context, "inactive", "Inactive", false, 1);
        await context.SaveChangesAsync();
        var service = new ProductService(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, Request(category.Id, "", "Description", 10m), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, Request(category.Id, "Name", "Description", 10m, null), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, Request(category.Id, "Name", "Description", -1m), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, Request(category.Id, "Name", "Description", null, null, -1), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, new CreateProductRequestDto(category.Id, "Name", "Description", null, null, null, (ProductCondition)99, null), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.CreateAsync(owner.Id, Request(category.Id, "Name", "Description", 10m), default));
    }

    [Fact]
    public async Task Product_list_rejects_unknown_sort()
    {
        await using var context = CreateContext();
        var service = new ProductService(context);

        await Assert.ThrowsAsync<ValidationException>(() => service.GetActiveAsync(new ProductListQueryDto(Sort: "arbitraryProperty"), Guid.NewGuid(), default));
    }

    [Fact]
    public async Task Favorites_are_idempotent_isolated_and_exclude_inactive_products()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var user = AddUser(context, "user");
        var other = AddUser(context, "other");
        var active = AddCategory(context, "active", "Active", true, 1);
        var inactive = AddCategory(context, "inactive", "Inactive", false, 2);
        var visible = new Product { SellerUserId = owner.Id, CategoryId = active.Id, Name = "Visible", Description = "", Status = ProductStatus.Active };
        var hidden = new Product { SellerUserId = owner.Id, CategoryId = inactive.Id, Name = "Hidden", Description = "", Status = ProductStatus.Active };
        context.Users.AddRange(owner, user, other);
        context.ProductCategories.AddRange(active, inactive);
        context.Products.AddRange(visible, hidden);
        await context.SaveChangesAsync();
        var service = new FavoriteService(context);

        await service.AddAsync(user.Id, visible.Id, default);
        await service.AddAsync(user.Id, visible.Id, default);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.AddAsync(user.Id, hidden.Id, default));
        Assert.Single(await service.GetMineAsync(user.Id, default));
        Assert.Empty(await service.GetMineAsync(other.Id, default));
        await service.RemoveAsync(user.Id, visible.Id, default);
        await service.RemoveAsync(user.Id, visible.Id, default);
        Assert.Empty(await service.GetMineAsync(user.Id, default));
    }

    [Fact]
    public async Task Product_update_accepts_current_row_version_and_returns_it()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        await context.SaveChangesAsync();
        var service = new ProductService(context);
        var product = await service.CreateAsync(owner.Id, Request(category.Id, "Part", "Description", null), default);

        var updated = await service.UpdateAsync(owner.Id, product.Id,
            new UpdateProductRequestDto(category.Id, "Changed", "Description", null, null, null, ProductCondition.Used, null, product.RowVersion), default);

        Assert.Equal("Changed", updated.Name);
        Assert.Equal(product.RowVersion, updated.RowVersion);
    }

    [Fact]
    public async Task Product_update_rejects_stale_or_invalid_row_version()
    {
        await using var context = CreateContext();
        var owner = AddUser(context, "owner");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        await context.SaveChangesAsync();
        var service = new ProductService(context);
        var product = await service.CreateAsync(owner.Id, Request(category.Id, "Part", "Description", null), default);
        var request = (string rowVersion) => new UpdateProductRequestDto(category.Id, "Changed", "Description", null, null, null, ProductCondition.Used, null, rowVersion);

        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateAsync(owner.Id, product.Id, request(Convert.ToBase64String([9])), default));
        await Assert.ThrowsAsync<ValidationException>(() => service.UpdateAsync(owner.Id, product.Id, request("not-base64"), default));
    }

    [Fact]
    public async Task Delivery_search_is_limited_to_paid_participants_and_nearby_opted_in_drivers()
    {
        await using var context = CreateContext();
        var buyer = AddUser(context, "buyer");
        var seller = AddUser(context, "seller");
        var nearbyDriver = AddUser(context, "nearby-driver", "Nearby", "Driver");
        var distantDriver = AddUser(context, "distant-driver");
        var stranger = AddUser(context, "stranger");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        var product = new Product { SellerUserId = seller.Id, CategoryId = category.Id, Name = "Part", Description = "Description", Status = ProductStatus.Active, Latitude = -12.0464m, Longitude = -77.0428m };
        var transaction = new ProductTransaction { Product = product, SellerUserId = seller.Id, BuyerUserId = buyer.Id, OfferedAmount = 100m, Currency = "PEN", PaymentMethod = "cash", Status = ProductTransactionStatus.Paid };
        context.Products.Add(product);
        context.ProductTransactions.Add(transaction);
        await context.SaveChangesAsync();
        var service = new DeliveryService(context);
        await service.UpdateDriverAvailabilityAsync(nearbyDriver.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-12.05m, -77.04m, true), default);
        await service.UpdateDriverAvailabilityAsync(distantDriver.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-13m, -77m, true), default);

        var drivers = await service.GetNearbyDriversAsync(buyer.Id, transaction.Id, default);

        var onlyDriver = Assert.Single(drivers);
        Assert.Equal(nearbyDriver.Id, onlyDriver.UserId);
        Assert.Equal("Nearby Driver", onlyDriver.DisplayName);
        await Assert.ThrowsAsync<ResourceNotFoundException>(() => service.GetNearbyDriversAsync(stranger.Id, transaction.Id, default));
    }

    [Fact]
    public async Task Delivery_request_assigns_selected_driver_and_only_driver_can_update_location()
    {
        await using var context = CreateContext();
        var buyer = AddUser(context, "buyer");
        var seller = AddUser(context, "seller");
        var driver = AddUser(context, "driver");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        var product = new Product { SellerUserId = seller.Id, CategoryId = category.Id, Name = "Part", Description = "Description", Status = ProductStatus.Active, Latitude = -12.0464m, Longitude = -77.0428m };
        var transaction = new ProductTransaction { Product = product, SellerUserId = seller.Id, BuyerUserId = buyer.Id, OfferedAmount = 100m, Currency = "PEN", PaymentMethod = "cash", Status = ProductTransactionStatus.Paid };
        context.Products.Add(product);
        context.ProductTransactions.Add(transaction);
        await context.SaveChangesAsync();
        var service = new DeliveryService(context);
        await service.UpdateDriverAvailabilityAsync(driver.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-12.05m, -77.04m, true), default);

        var delivery = await service.RequestAsync(buyer.Id, transaction.Id, new CreateDeliveryRequestDto(-12.1m, -77.1m, driver.Id), default);

        Assert.Equal(driver.Id, delivery.DriverUserId);
        Assert.Equal(product.Latitude, delivery.PickupLatitude);
        Assert.Equal(product.Longitude, delivery.PickupLongitude);
        Assert.False((await context.DeliveryDriverProfiles.SingleAsync(x => x.UserId == driver.Id)).IsAvailable);
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateDriverAvailabilityAsync(driver.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-12.05m, -77.04m, true), default));
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => service.UpdateLocationAsync(seller.Id, transaction.Id, new UpdateDeliveryLocationRequestDto(-12.1m, -77.1m), default));
        var updated = await service.UpdateLocationAsync(driver.Id, transaction.Id, new UpdateDeliveryLocationRequestDto(-12.1m, -77.1m), default);
        Assert.Equal(DeliveryStatus.Near, updated.Status);
    }

    [Fact]
    public async Task Driver_availability_requires_confirmed_profile_and_a_motorcycle_with_registration_data()
    {
        await using var context = CreateContext();
        var qualified = AddUser(context, "qualified-driver", "Ana", "Rider");
        qualified.EmailConfirmed = true;
        qualified.PhoneNumber = "+51999111222";
        var unqualified = AddUser(context, "unqualified-driver");
        context.Motorcycles.Add(new Motorcycle { OwnerUserId = qualified.Id, Brand = "Honda", Model = "CB", Year = 2022, LicensePlate = "ABC-123", Vin = "VIN123456789" });
        await context.SaveChangesAsync();
        var service = new DeliveryService(context);

        var eligibility = await service.GetDriverEligibilityAsync(qualified.Id, default);
        Assert.True(eligibility.IsEligible);
        await service.UpdateDriverAvailabilityAsync(qualified.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-12.05m, -77.04m, true), default);
        Assert.False((await service.GetDriverEligibilityAsync(unqualified.Id, default)).IsEligible);
        await Assert.ThrowsAsync<ConflictException>(() => service.UpdateDriverAvailabilityAsync(unqualified.Id, new UpdateDeliveryDriverAvailabilityRequestDto(-12.05m, -77.04m, true), default));
    }

    [Fact]
    public async Task Completed_transaction_allows_both_participants_to_review_each_other_and_reports_reputation_by_role()
    {
        await using var context = CreateContext();
        var buyer = AddUser(context, "buyer");
        var seller = AddUser(context, "seller");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        var product = new Product { SellerUserId = seller.Id, CategoryId = category.Id, Name = "Part", Description = "Description", Status = ProductStatus.Sold };
        var transaction = new ProductTransaction { Product = product, SellerUserId = seller.Id, BuyerUserId = buyer.Id, OfferedAmount = 100m, Currency = "PEN", PaymentMethod = "cash", Status = ProductTransactionStatus.Completed };
        context.Products.Add(product);
        context.ProductTransactions.Add(transaction);
        await context.SaveChangesAsync();
        var service = new ProductTransactionService(context);

        var sellerReview = await service.AddReviewAsync(buyer.Id, transaction.Id, new CreateProductTransactionReviewRequestDto(5, "Venta correcta"), default);
        var buyerReview = await service.AddReviewAsync(seller.Id, transaction.Id, new CreateProductTransactionReviewRequestDto(4, "Pago puntual"), default);
        var reputation = await service.GetReputationAsync(seller.Id, transaction.Id, default);

        Assert.Equal(seller.Id, sellerReview.ReviewedUserId);
        Assert.Equal(buyer.Id, buyerReview.ReviewedUserId);
        Assert.Equal(5m, reputation.Seller.AverageRating);
        Assert.Equal(1, reputation.Seller.RatingCount);
        Assert.Equal(1, reputation.Seller.SuccessfulSales);
        Assert.Equal(4m, reputation.Buyer.AverageRating);
        Assert.Equal(1, reputation.Buyer.RatingCount);
        Assert.Equal(1, reputation.Buyer.SuccessfulPurchases);
        await Assert.ThrowsAsync<ConflictException>(() => service.AddReviewAsync(buyer.Id, transaction.Id, new CreateProductTransactionReviewRequestDto(3, null), default));
    }

    [Fact]
    public async Task Offer_acceptance_and_payment_create_marketplace_notifications_for_the_other_participant()
    {
        await using var context = CreateContext();
        var buyer = AddUser(context, "buyer");
        var seller = AddUser(context, "seller");
        var category = AddCategory(context, "parts", "Parts", true, 1);
        var product = new Product
        {
            SellerUserId = seller.Id,
            CategoryId = category.Id,
            Name = "Casco",
            Description = "Casco de prueba",
            Status = ProductStatus.Active
        };
        context.Users.AddRange(buyer, seller);
        context.ProductCategories.Add(category);
        context.Products.Add(product);
        await context.SaveChangesAsync();
        var service = new ProductTransactionService(context);

        var offer = await service.CreateAsync(
            buyer.Id,
            product.Id,
            new CreateProductTransactionRequestDto(120m, "PEN", "Efectivo"),
            default);
        await service.ChangeStatusAsync(seller.Id, offer.Id, "accept", null, default);
        await service.ChangeStatusAsync(buyer.Id, offer.Id, "paid", null, default);

        var notifications = await context.Notifications.OrderBy(x => x.CreatedAt).ToListAsync();
        Assert.Equal(3, notifications.Count);
        Assert.Collection(
            notifications,
            notification => AssertNotification(notification, seller.Id, buyer.Id, "Nueva oferta recibida", product.Id),
            notification => AssertNotification(notification, buyer.Id, seller.Id, "Oferta aceptada", product.Id),
            notification => AssertNotification(notification, seller.Id, buyer.Id, "Pago marcado como realizado", product.Id));
    }

    private static void AssertNotification(
        Notification notification,
        Guid recipientId,
        Guid actorId,
        string title,
        Guid productId)
    {
        Assert.Equal(recipientId, notification.RecipientUserId);
        Assert.Equal(actorId, notification.ActorUserId);
        Assert.Equal(NotificationType.Marketplace, notification.Type);
        Assert.Equal(title, notification.Title);
        using var target = JsonDocument.Parse(notification.DataJson!);
        Assert.Equal("Product", target.RootElement.GetProperty("resourceType").GetString());
        Assert.Equal(productId, target.RootElement.GetProperty("resourceId").GetGuid());
    }

    private static CreateProductRequestDto Request(Guid categoryId, string name, string description, decimal? price, string? currency = "PEN", int? stockQuantity = null)
        => new(categoryId, name, description, price, currency, stockQuantity, ProductCondition.Used, " Lima ");

    private static User AddUser(MotoHubDbContext context, string userName, string? firstName = null, string? lastName = null, string? email = null)
    {
        var user = new User(Guid.NewGuid()) { UserName = userName, NormalizedUserName = userName.ToUpperInvariant(), Email = email ?? $"{userName}@example.com", NormalizedEmail = (email ?? $"{userName}@example.com").ToUpperInvariant(), FirstName = firstName, LastName = lastName };
        context.Users.Add(user);
        return user;
    }

    private static ProductCategory AddCategory(MotoHubDbContext context, string slug, string name, bool active, int order)
    {
        var category = new ProductCategory { Name = name, Slug = slug, IsActive = active, DisplayOrder = order };
        context.ProductCategories.Add(category);
        return category;
    }

    private static MotoHubDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<MotoHubDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        return new MotoHubDbContext(options);
    }
}
