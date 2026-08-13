using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class ReportConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<ModerationReport>().ToTable("ModerationReports");
        ConfigureReport<UserReport>(builder, "UserReports", (e, x) => e.HasOne(x => x.ReportedUser).WithMany().HasForeignKey(x => x.ReportedUserId).OnDelete(DeleteBehavior.Restrict));
        ConfigureReport<PostReport>(builder, "PostReports", (e, x) => e.HasOne(x => x.Post).WithMany().HasForeignKey(x => x.PostId).OnDelete(DeleteBehavior.Restrict));
        ConfigureReport<CommentReport>(builder, "CommentReports", (e, x) => e.HasOne(x => x.PostComment).WithMany().HasForeignKey(x => x.PostCommentId).OnDelete(DeleteBehavior.Restrict));
        ConfigureReport<ProductReport>(builder, "ProductReports", (e, x) => e.HasOne(x => x.Product).WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict));
        ConfigureReport<MessageReport>(builder, "MessageReports", (e, x) => e.HasOne(x => x.Message).WithMany().HasForeignKey(x => x.MessageId).OnDelete(DeleteBehavior.Restrict));
    }

    private static void ConfigureReport<T>(ModelBuilder builder, string table, Action<EntityTypeBuilder<T>, T> target) where T : ModerationReport
    {
        builder.Entity<T>(e => { e.ToTable(table); e.Property(x => x.Reason).HasMaxLength(100).IsRequired(); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => new { x.Status, x.CreatedAt }); e.HasOne(x => x.Reporter).WithMany().HasForeignKey(x => x.ReporterUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.ResolvedByUser).WithMany().HasForeignKey(x => x.ResolvedByUserId).OnDelete(DeleteBehavior.NoAction); target(e, null!); });
    }
}