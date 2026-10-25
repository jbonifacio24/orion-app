using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class MarketplaceConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<ProductCategory>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "ProductCategories");
            e.Property(x => x.Name).HasMaxLength(150).IsRequired();
            e.Property(x => x.Slug).HasMaxLength(180).IsRequired();
            e.HasIndex(x => x.Slug).IsUnique();
            e.HasOne(x => x.ParentCategory).WithMany(x => x.Children).HasForeignKey(x => x.ParentCategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<Product>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Products");
            e.Property(x => x.Name).HasMaxLength(200).IsRequired();
            e.Property(x => x.Description).HasMaxLength(10000).IsRequired();
            e.Property(x => x.Price).HasPrecision(18, 2);
            e.Property(x => x.Currency).HasMaxLength(3);
            e.Property(x => x.Condition).HasConversion<string>().HasMaxLength(40).IsRequired();
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired();
            e.Property(x => x.Location).HasMaxLength(500);
            e.Property(x => x.Latitude).HasPrecision(9, 6);
            e.Property(x => x.Longitude).HasPrecision(9, 6);
            e.Property(x => x.PaymentMethod).HasMaxLength(50);
            e.ToTable("Products", table => { table.HasCheckConstraint("CK_Products_Price", "[Price] IS NULL OR [Price] >= 0"); table.HasCheckConstraint("CK_Products_StockQuantity", "[StockQuantity] IS NULL OR [StockQuantity] >= 0"); table.HasCheckConstraint("CK_Products_Latitude", "[Latitude] IS NULL OR ([Latitude] >= -90 AND [Latitude] <= 90)"); table.HasCheckConstraint("CK_Products_Longitude", "[Longitude] IS NULL OR ([Longitude] >= -180 AND [Longitude] <= 180)"); });
            e.HasIndex(x => new { x.Status, x.CreatedAt });
            e.HasOne(x => x.Seller).WithMany(x => x.Products).HasForeignKey(x => x.SellerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Category).WithMany(x => x.Products).HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<ProductTransaction>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "ProductTransactions", false);
            e.Property(x => x.OfferedAmount).HasPrecision(18, 2).IsRequired();
            e.Property(x => x.Currency).HasMaxLength(3).IsRequired();
            e.Property(x => x.PaymentMethod).HasMaxLength(50).IsRequired();
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20).IsRequired();
            e.Property(x => x.CancellationReason).HasMaxLength(1000);
            e.ToTable("ProductTransactions", table => table.HasCheckConstraint("CK_ProductTransactions_OfferedAmount", "[OfferedAmount] >= 0"));
            e.HasIndex(x => new { x.BuyerUserId, x.CreatedAt });
            e.HasIndex(x => new { x.SellerUserId, x.CreatedAt });
            e.HasOne(x => x.Product).WithMany(x => x.Transactions).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Seller).WithMany().HasForeignKey(x => x.SellerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Buyer).WithMany().HasForeignKey(x => x.BuyerUserId).OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<ProductTransactionReview>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "ProductTransactionReviews", false);
            e.Property(x => x.Rating).IsRequired();
            e.Property(x => x.Comment).HasMaxLength(2000);
            e.HasIndex(x => new { x.ProductTransactionId, x.ReviewerUserId }).IsUnique();
            e.HasCheckConstraint("CK_ProductTransactionReviews_Rating", "[Rating] BETWEEN 1 AND 5");
            e.HasOne(x => x.Transaction).WithMany(x => x.Reviews).HasForeignKey(x => x.ProductTransactionId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Reviewer).WithMany().HasForeignKey(x => x.ReviewerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.ReviewedUser).WithMany().HasForeignKey(x => x.ReviewedUserId).OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<Delivery>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Deliveries", false);
            e.Property(x => x.Status).HasConversion<string>().HasMaxLength(20).IsRequired();
            e.Property(x => x.DestinationLatitude).HasPrecision(9, 6);
            e.Property(x => x.DestinationLongitude).HasPrecision(9, 6);
            e.Property(x => x.PickupLatitude).HasPrecision(9, 6);
            e.Property(x => x.PickupLongitude).HasPrecision(9, 6);
            e.Property(x => x.DriverLatitude).HasPrecision(9, 6);
            e.Property(x => x.DriverLongitude).HasPrecision(9, 6);
            e.HasIndex(x => x.ProductTransactionId).IsUnique();
            e.ToTable("Deliveries", table =>
            {
                table.HasCheckConstraint("CK_Deliveries_DestinationCoordinates", "[DestinationLatitude] >= -90 AND [DestinationLatitude] <= 90 AND [DestinationLongitude] >= -180 AND [DestinationLongitude] <= 180");
                table.HasCheckConstraint("CK_Deliveries_PickupCoordinates", "([PickupLatitude] IS NULL AND [PickupLongitude] IS NULL) OR ([PickupLatitude] >= -90 AND [PickupLatitude] <= 90 AND [PickupLongitude] >= -180 AND [PickupLongitude] <= 180)");
                table.HasCheckConstraint("CK_Deliveries_DriverCoordinates", "([DriverLatitude] IS NULL AND [DriverLongitude] IS NULL) OR ([DriverLatitude] >= -90 AND [DriverLatitude] <= 90 AND [DriverLongitude] >= -180 AND [DriverLongitude] <= 180)");
            });
            e.HasOne(x => x.ProductTransaction).WithOne(x => x.Delivery).HasForeignKey<Delivery>(x => x.ProductTransactionId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne(x => x.Buyer).WithMany().HasForeignKey(x => x.BuyerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Seller).WithMany().HasForeignKey(x => x.SellerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Driver).WithMany().HasForeignKey(x => x.DriverUserId).OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<DeliveryDriverProfile>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "DeliveryDriverProfiles", false);
            e.Property(x => x.Latitude).HasPrecision(9, 6);
            e.Property(x => x.Longitude).HasPrecision(9, 6);
            e.HasIndex(x => x.UserId).IsUnique();
            e.ToTable("DeliveryDriverProfiles", table =>
            {
                table.HasCheckConstraint("CK_DeliveryDriverProfiles_Latitude", "[Latitude] >= -90 AND [Latitude] <= 90");
                table.HasCheckConstraint("CK_DeliveryDriverProfiles_Longitude", "[Longitude] >= -180 AND [Longitude] <= 180");
            });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<ProductImage>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "ProductImages", false);
            e.Property(x => x.StorageKey).HasMaxLength(500).IsRequired();
            e.Property(x => x.Url).HasMaxLength(1000).IsRequired();
            e.Property(x => x.ThumbnailUrl).HasMaxLength(1000);
            e.HasIndex(x => new { x.ProductId, x.DisplayOrder }).IsUnique();
            e.HasIndex(x => new { x.ProductId, x.IsPrimary }).HasFilter("[IsPrimary] = 1").IsUnique();
            e.HasOne(x => x.Product).WithMany(x => x.Images).HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<ProductFavorite>(e =>
        {
            e.HasKey(x => new { x.UserId, x.ProductId });
            e.ToTable("ProductFavorites");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<MotorcycleFavorite>(e =>
        {
            e.HasKey(x => new { x.UserId, x.MotorcycleId });
            e.ToTable("MotorcycleFavorites");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Motorcycle).WithMany().HasForeignKey(x => x.MotorcycleId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<WorkshopFavorite>(e =>
        {
            e.HasKey(x => new { x.UserId, x.WorkshopId });
            e.ToTable("WorkshopFavorites");
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Workshop).WithMany().HasForeignKey(x => x.WorkshopId).OnDelete(DeleteBehavior.Cascade);
        });
    }
}