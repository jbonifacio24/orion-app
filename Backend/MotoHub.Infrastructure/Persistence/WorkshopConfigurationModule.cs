using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class WorkshopConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<Workshop>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Workshops"); e.Property(x => x.Name).HasMaxLength(200).IsRequired(); e.Property(x => x.Description).HasMaxLength(5000); e.Property(x => x.PhoneNumber).HasMaxLength(30); e.Property(x => x.Email).HasMaxLength(320); e.Property(x => x.Address).HasMaxLength(500); e.Property(x => x.City).HasMaxLength(100); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired();
            e.ToTable("Workshops", table => table.HasCheckConstraint("CK_Workshops_Coordinates", "([Latitude] IS NULL OR [Latitude] BETWEEN -90 AND 90) AND ([Longitude] IS NULL OR [Longitude] BETWEEN -180 AND 180)"));
            e.Property(x => x.Latitude).HasPrecision(9, 6); e.Property(x => x.Longitude).HasPrecision(9, 6); e.HasIndex(x => new { x.City, x.Status });
            e.HasOne(x => x.Owner).WithMany(x => x.Workshops).HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict); e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<WorkshopSchedule>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "WorkshopSchedules"); e.ToTable("WorkshopSchedules", table => { table.HasCheckConstraint("CK_WorkshopSchedules_DayOfWeek", "[DayOfWeek] BETWEEN 0 AND 6"); table.HasCheckConstraint("CK_WorkshopSchedules_TimeRange", "[IsClosed] = 1 OR ([OpenTime] IS NOT NULL AND [CloseTime] IS NOT NULL AND [CloseTime] > [OpenTime])"); }); e.HasIndex(x => new { x.WorkshopId, x.DayOfWeek, x.OpenTime, x.CloseTime }).IsUnique();
            e.HasOne(x => x.Workshop).WithMany(x => x.Schedules).HasForeignKey(x => x.WorkshopId).OnDelete(DeleteBehavior.Cascade);
        });
        builder.Entity<WorkshopService>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "WorkshopServices"); e.Property(x => x.Name).HasMaxLength(200).IsRequired(); e.Property(x => x.Price).HasPrecision(18, 2); e.HasIndex(x => new { x.WorkshopId, x.Name }).IsUnique();
            e.HasOne(x => x.Workshop).WithMany(x => x.Services).HasForeignKey(x => x.WorkshopId).OnDelete(DeleteBehavior.Cascade); e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<WorkshopReview>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "WorkshopReviews"); e.Property(x => x.Comment).HasMaxLength(5000); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.ToTable("WorkshopReviews", table => table.HasCheckConstraint("CK_WorkshopReviews_Rating", "[Rating] BETWEEN 1 AND 5")); e.HasIndex(x => new { x.AuthorUserId, x.WorkshopId }).IsUnique();
            e.HasOne(x => x.Author).WithMany().HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.Workshop).WithMany().HasForeignKey(x => x.WorkshopId).OnDelete(DeleteBehavior.Restrict); e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<ProductReview>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "ProductReviews"); e.Property(x => x.Comment).HasMaxLength(5000); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.ToTable("ProductReviews", table => table.HasCheckConstraint("CK_ProductReviews_Rating", "[Rating] BETWEEN 1 AND 5")); e.HasIndex(x => new { x.AuthorUserId, x.ProductId }).IsUnique();
            e.HasOne(x => x.Author).WithMany().HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict); e.HasQueryFilter(x => !x.IsDeleted);
        });
    }
}