using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using MotoHub.Domain;
using MotoHub.Infrastructure.Authentication;

namespace MotoHub.Infrastructure.Persistence;

public sealed class MotoHubDbContext(DbContextOptions<MotoHubDbContext> options)
    : IdentityDbContext<MotoHubIdentityUser, MotoHubIdentityRole, Guid>(options)
{
    public new DbSet<User> Users => Set<User>();
    public new DbSet<Role> Roles => Set<Role>();
    public new DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Motorcycle> Motorcycles => Set<Motorcycle>();
    public DbSet<MotorcycleImage> MotorcycleImages => Set<MotorcycleImage>();
    public DbSet<ProductCategory> ProductCategories => Set<ProductCategory>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<ProductImage> ProductImages => Set<ProductImage>();
    public DbSet<ProductFavorite> ProductFavorites => Set<ProductFavorite>();
    public DbSet<MotorcycleFavorite> MotorcycleFavorites => Set<MotorcycleFavorite>();
    public DbSet<WorkshopFavorite> WorkshopFavorites => Set<WorkshopFavorite>();
    public DbSet<Workshop> Workshops => Set<Workshop>();
    public DbSet<WorkshopSchedule> WorkshopSchedules => Set<WorkshopSchedule>();
    public DbSet<WorkshopService> WorkshopServices => Set<WorkshopService>();
    public DbSet<WorkshopReview> WorkshopReviews => Set<WorkshopReview>();
    public DbSet<ProductReview> ProductReviews => Set<ProductReview>();
    public DbSet<TheftReport> TheftReports => Set<TheftReport>();
    public DbSet<TheftAlertRecipient> TheftAlertRecipients => Set<TheftAlertRecipient>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<UserDevice> UserDevices => Set<UserDevice>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationParticipant> ConversationParticipants => Set<ConversationParticipant>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<MessageAttachment> MessageAttachments => Set<MessageAttachment>();
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<PostMedia> PostMedia => Set<PostMedia>();
    public DbSet<PostComment> PostComments => Set<PostComment>();
    public DbSet<PostLike> PostLikes => Set<PostLike>();
    public DbSet<News> News => Set<News>();
    public DbSet<NewsCategory> NewsCategories => Set<NewsCategory>();
    public DbSet<NewsCategoryAssignment> NewsCategoryAssignments => Set<NewsCategoryAssignment>();
    public DbSet<Referral> Referrals => Set<Referral>();
    public DbSet<ReferralReward> ReferralRewards => Set<ReferralReward>();
    public DbSet<SubscriptionPlan> SubscriptionPlans => Set<SubscriptionPlan>();
    public DbSet<Subscription> Subscriptions => Set<Subscription>();
    public DbSet<UserReport> UserReports => Set<UserReport>();
    public DbSet<PostReport> PostReports => Set<PostReport>();
    public DbSet<CommentReport> CommentReports => Set<CommentReport>();
    public DbSet<ProductReport> ProductReports => Set<ProductReport>();
    public DbSet<MessageReport> MessageReports => Set<MessageReport>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ApplyTimestamps();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        ApplyTimestamps();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private void ApplyTimestamps()
    {
        var now = DateTimeOffset.UtcNow;
        foreach (var entry in ChangeTracker.Entries<Entity>())
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAt = now;
                entry.Entity.UpdatedAt = now;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = now;
            }

            if (entry.Entity is SoftDeletableEntity softDelete && entry.State == EntityState.Modified)
            {
                var deletedProperty = entry.Property(nameof(SoftDeletableEntity.IsDeleted));
                if ((bool)deletedProperty.CurrentValue! && !(bool)deletedProperty.OriginalValue!)
                {
                    softDelete.DeletedAt = now;
                }
                else if (!(bool)deletedProperty.CurrentValue! && (bool)deletedProperty.OriginalValue!)
                {
                    softDelete.DeletedAt = null;
                }
            }
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        MotoHubModelConfiguration.Configure(modelBuilder);

        modelBuilder.Entity<MotoHubIdentityUser>().ToTable("AspNetUsers");
        modelBuilder.Entity<MotoHubIdentityRole>().ToTable("AspNetRoles");
        modelBuilder.Entity<IdentityUserRole<Guid>>().ToTable("AspNetUserRoles");
        modelBuilder.Entity<IdentityUserClaim<Guid>>().ToTable("AspNetUserClaims");
        modelBuilder.Entity<IdentityUserLogin<Guid>>().ToTable("AspNetUserLogins");
        modelBuilder.Entity<IdentityRoleClaim<Guid>>().ToTable("AspNetRoleClaims");
        modelBuilder.Entity<IdentityUserToken<Guid>>().ToTable("AspNetUserTokens");
    }
}