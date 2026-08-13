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
            e.ToTable("Products", table => { table.HasCheckConstraint("CK_Products_Price", "[Price] IS NULL OR [Price] >= 0"); table.HasCheckConstraint("CK_Products_StockQuantity", "[StockQuantity] IS NULL OR [StockQuantity] >= 0"); });
            e.HasIndex(x => new { x.Status, x.CreatedAt });
            e.HasOne(x => x.Seller).WithMany(x => x.Products).HasForeignKey(x => x.SellerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Category).WithMany(x => x.Products).HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.IsDeleted);
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