using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class BaseConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<User>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Users");
            e.Property(x => x.UserName).HasMaxLength(100).IsRequired();
            e.Property(x => x.NormalizedUserName).HasMaxLength(100).IsRequired();
            e.Property(x => x.Email).HasMaxLength(320).IsRequired();
            e.Property(x => x.NormalizedEmail).HasMaxLength(320).IsRequired();
            e.Property(x => x.PhoneNumber).HasMaxLength(30);
            e.Property(x => x.FirstName).HasMaxLength(100);
            e.Property(x => x.LastName).HasMaxLength(100);
            e.Property(x => x.ProfileImageUrl).HasMaxLength(1000);
            e.Property(x => x.Bio).HasMaxLength(2000);
            e.HasIndex(x => x.NormalizedEmail).IsUnique();
            e.HasIndex(x => x.NormalizedUserName).IsUnique();
            e.HasIndex(x => x.PhoneNumber).IsUnique().HasFilter("[PhoneNumber] IS NOT NULL");
            e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<Role>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "Roles");
            e.Property(x => x.Name).HasMaxLength(100).IsRequired();
            e.Property(x => x.NormalizedName).HasMaxLength(100).IsRequired();
            e.HasIndex(x => x.NormalizedName).IsUnique();
        });
        builder.Entity<UserRole>(e =>
        {
            e.HasKey(x => new { x.UserId, x.RoleId });
            e.ToTable("UserRoles");
            e.HasOne(x => x.User).WithMany(x => x.UserRoles).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.Role).WithMany(x => x.UserRoles).HasForeignKey(x => x.RoleId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.AssignedByUser).WithMany().HasForeignKey(x => x.AssignedByUserId).OnDelete(DeleteBehavior.NoAction);
        });
        builder.Entity<RefreshToken>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "RefreshTokens", false);
            e.Property(x => x.TokenHash).HasMaxLength(128).IsRequired();
            e.HasIndex(x => x.TokenHash).IsUnique();
            e.HasIndex(x => new { x.UserId, x.ExpiresAt });
            e.HasOne(x => x.User).WithMany(x => x.RefreshTokens).HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne(x => x.ReplacedByToken).WithMany().HasForeignKey(x => x.ReplacedByTokenId).OnDelete(DeleteBehavior.NoAction);
        });
        builder.Entity<AuditLog>(e =>
        {
            e.HasKey(x => x.Id);
            e.ToTable("AuditLogs");
            e.Property(x => x.Action).HasMaxLength(100).IsRequired();
            e.Property(x => x.EntityType).HasMaxLength(100).IsRequired();
            e.Property(x => x.IpAddress).HasMaxLength(45);
            e.Property(x => x.CorrelationId).HasMaxLength(100);
            e.HasIndex(x => new { x.EntityType, x.EntityId, x.CreatedAt });
            e.HasIndex(x => new { x.ActorUserId, x.CreatedAt });
            e.HasOne(x => x.ActorUser).WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.NoAction);
        });
    }
}