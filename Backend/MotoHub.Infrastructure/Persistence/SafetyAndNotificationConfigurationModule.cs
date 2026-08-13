using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class SafetyAndNotificationConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<TheftReport>(e =>
        {
            EntityConfigurationHelper.ConfigureEntity(e, "TheftReports"); e.Property(x => x.Title).HasMaxLength(200).IsRequired(); e.Property(x => x.Description).HasMaxLength(10000).IsRequired(); e.Property(x => x.Vin).HasMaxLength(100); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => new { x.Status, x.CreatedAt });
            e.ToTable("TheftReports", table => table.HasCheckConstraint("CK_TheftReports_Coordinates", "([Latitude] IS NULL OR [Latitude] BETWEEN -90 AND 90) AND ([Longitude] IS NULL OR [Longitude] BETWEEN -180 AND 180)")); e.HasOne(x => x.Reporter).WithMany().HasForeignKey(x => x.ReporterUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.Motorcycle).WithMany().HasForeignKey(x => x.MotorcycleId).OnDelete(DeleteBehavior.NoAction); e.HasQueryFilter(x => !x.IsDeleted);
        });
        builder.Entity<TheftAlertRecipient>(e =>
        {
            e.HasKey(x => new { x.TheftReportId, x.UserId }); e.ToTable("TheftAlertRecipients"); e.HasIndex(x => new { x.UserId, x.ReadAt });
            e.HasOne(x => x.TheftReport).WithMany(x => x.AlertRecipients).HasForeignKey(x => x.TheftReportId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);
        });
        builder.Entity<Notification>(e => { EntityConfigurationHelper.ConfigureEntity(e, "Notifications", false); e.Property(x => x.Type).HasConversion<string>().HasMaxLength(40).IsRequired(); e.Property(x => x.Title).HasMaxLength(200).IsRequired(); e.Property(x => x.Body).HasMaxLength(2000).IsRequired(); e.HasIndex(x => new { x.RecipientUserId, x.ReadAt, x.CreatedAt }); e.HasOne(x => x.Recipient).WithMany().HasForeignKey(x => x.RecipientUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.Actor).WithMany().HasForeignKey(x => x.ActorUserId).OnDelete(DeleteBehavior.NoAction); });
        builder.Entity<UserDevice>(e => { EntityConfigurationHelper.ConfigureEntity(e, "UserDevices", false); e.Property(x => x.DeviceId).HasMaxLength(200).IsRequired(); e.Property(x => x.PushTokenCiphertext).HasMaxLength(2000).IsRequired(); e.Property(x => x.Platform).HasMaxLength(30).IsRequired(); e.HasIndex(x => new { x.UserId, x.DeviceId }).IsUnique(); e.HasIndex(x => x.PushTokenCiphertext).IsUnique(); e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade); });
    }
}