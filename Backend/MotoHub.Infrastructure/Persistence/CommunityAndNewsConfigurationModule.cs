using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;

namespace MotoHub.Infrastructure.Persistence;

internal sealed class CommunityAndNewsConfigurationModule : IModelConfigurationModule
{
    public void Configure(ModelBuilder builder)
    {
        builder.Entity<Post>(e => { EntityConfigurationHelper.ConfigureEntity(e, "Posts"); e.Property(x => x.Content).HasMaxLength(20000).IsRequired(); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => new { x.Status, x.PublishedAt }); e.HasOne(x => x.Author).WithMany(x => x.Posts).HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.Restrict); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<PostMedia>(e => { EntityConfigurationHelper.ConfigureEntity(e, "PostMedia", false); e.Property(x => x.StorageKey).HasMaxLength(500).IsRequired(); e.HasIndex(x => new { x.PostId, x.DisplayOrder }).IsUnique(); e.HasOne(x => x.Post).WithMany(x => x.Media).HasForeignKey(x => x.PostId).OnDelete(DeleteBehavior.Cascade); });
        builder.Entity<PostComment>(e => { EntityConfigurationHelper.ConfigureEntity(e, "PostComments"); e.Property(x => x.Content).HasMaxLength(5000).IsRequired(); e.HasIndex(x => new { x.PostId, x.CreatedAt }); e.HasOne(x => x.Post).WithMany(x => x.Comments).HasForeignKey(x => x.PostId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.Author).WithMany().HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.Restrict); e.HasOne(x => x.ParentComment).WithMany(x => x.Replies).HasForeignKey(x => x.ParentCommentId).OnDelete(DeleteBehavior.NoAction); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<PostLike>(e => { e.HasKey(x => new { x.PostId, x.UserId }); e.ToTable("PostLikes"); e.HasOne(x => x.Post).WithMany(x => x.Likes).HasForeignKey(x => x.PostId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict); });
        builder.Entity<News>(e => { EntityConfigurationHelper.ConfigureEntity(e, "News"); e.Property(x => x.Title).HasMaxLength(250).IsRequired(); e.Property(x => x.Slug).HasMaxLength(280).IsRequired(); e.Property(x => x.Content).HasMaxLength(50000).IsRequired(); e.Property(x => x.Status).HasConversion<string>().HasMaxLength(40).IsRequired(); e.HasIndex(x => x.Slug).IsUnique(); e.HasIndex(x => new { x.Status, x.PublishedAt }); e.HasOne(x => x.Author).WithMany().HasForeignKey(x => x.AuthorUserId).OnDelete(DeleteBehavior.NoAction); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<NewsCategory>(e => { EntityConfigurationHelper.ConfigureEntity(e, "NewsCategories"); e.Property(x => x.Name).HasMaxLength(150).IsRequired(); e.Property(x => x.Slug).HasMaxLength(180).IsRequired(); e.HasIndex(x => x.Slug).IsUnique(); e.HasQueryFilter(x => !x.IsDeleted); });
        builder.Entity<NewsCategoryAssignment>(e => { e.HasKey(x => new { x.NewsId, x.NewsCategoryId }); e.ToTable("NewsCategoryAssignments"); e.HasOne(x => x.News).WithMany(x => x.Categories).HasForeignKey(x => x.NewsId).OnDelete(DeleteBehavior.Cascade); e.HasOne(x => x.Category).WithMany(x => x.News).HasForeignKey(x => x.NewsCategoryId).OnDelete(DeleteBehavior.Restrict); });
    }
}