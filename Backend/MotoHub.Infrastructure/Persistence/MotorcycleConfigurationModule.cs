using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class MotorcycleConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<Motorcycle>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Motorcycles");
            e.Property(x => x.Brand).HasMaxLength(100).IsRequired();
            e.Property(x => x.Model).HasMaxLength(100).IsRequired();
            e.Property(x => x.Vin).HasMaxLength(100);
            e.Property(x => x.Color).HasMaxLength(50);
            e.Property(x => x.Description).HasMaxLength(5000);
            e.Property(x => x.LicensePlate).HasMaxLength(30);
            e.Property(x => x.Year).HasColumnType("int");
            e.ToTable("Motorcycles", table => { table.HasCheckConstraint("CK_Motorcycles_Year", "[Year] BETWEEN 1885 AND 2200"); table.HasCheckConstraint("CK_Motorcycles_Displacement", "[Displacement] IS NULL OR [Displacement] > 0"); });
            e.HasIndex(x => new { x.OwnerUserId, x.IsPrimary }).HasFilter("[IsPrimary] = 1 AND [IsDeleted] = 0").IsUnique();
            e.HasIndex(x => x.Vin).IsUnique().HasFilter("[Vin] IS NOT NULL AND [IsDeleted] = 0");
            e.HasOne(x => x.Owner).WithMany(x => x.Motorcycles).HasForeignKey(x => x.OwnerUserId).OnDelete(DeleteBehavior.Restrict);
            e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<MotorcycleImage>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "MotorcycleImages", false);
            e.Property(x => x.StorageKey).HasMaxLength(500).IsRequired();
            e.Property(x => x.Url).HasMaxLength(1000).IsRequired();
            e.HasIndex(x => new { x.MotorcycleId, x.DisplayOrder }).IsUnique();
            e.HasIndex(x => new { x.MotorcycleId, x.IsPrimary }).HasFilter("[IsPrimary] = 1").IsUnique();
            e.HasOne(x => x.Motorcycle).WithMany(x => x.Images).HasForeignKey(x => x.MotorcycleId).OnDelete(DeleteBehavior.Cascade);
        });
    }
}