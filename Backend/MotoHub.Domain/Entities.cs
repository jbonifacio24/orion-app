namespace MotoHub.Domain;

public abstract class Entity
{
    public Guid Id { get; protected set; } = Guid.NewGuid();
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public byte[] RowVersion { get; set; } = [];
}

public abstract class SoftDeletableEntity : Entity
{
    public bool IsDeleted { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }
}

public sealed class User : SoftDeletableEntity
{
    public User() { }

    public User(Guid id)
    {
        Id = id;
    }

    public string UserName { get; set; } = string.Empty;
    public string NormalizedUserName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string NormalizedEmail { get; set; } = string.Empty;
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? PhoneNumber { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? Bio { get; set; }
    public bool IsActive { get; set; } = true;
    public bool EmailConfirmed { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
    public ICollection<UserRole> UserRoles { get; set; } = [];
    public ICollection<RefreshToken> RefreshTokens { get; set; } = [];
    public ICollection<Motorcycle> Motorcycles { get; set; } = [];
    public ICollection<Product> Products { get; set; } = [];
    public ICollection<Workshop> Workshops { get; set; } = [];
    public ICollection<Post> Posts { get; set; } = [];
}

public sealed class Role : Entity
{
    public string Name { get; set; } = string.Empty;
    public string NormalizedName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSystemRole { get; set; }
    public ICollection<UserRole> UserRoles { get; set; } = [];
}

public sealed class UserRole
{
    public Guid UserId { get; set; }
    public Guid RoleId { get; set; }
    public DateTimeOffset AssignedAt { get; set; } = DateTimeOffset.UtcNow;
    public Guid? AssignedByUserId { get; set; }
    public User User { get; set; } = null!;
    public Role Role { get; set; } = null!;
    public User? AssignedByUser { get; set; }
}

public sealed class RefreshToken : Entity
{
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public Guid? ReplacedByTokenId { get; set; }
    public string? CreatedByIp { get; set; }
    public string? RevokedByIp { get; set; }
    public string? RevocationReason { get; set; }
    public User User { get; set; } = null!;
    public RefreshToken? ReplacedByToken { get; set; }
}

public sealed class Motorcycle : SoftDeletableEntity
{
    public Guid OwnerUserId { get; set; }
    public string Brand { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public int Year { get; set; }
    public int? Displacement { get; set; }
    public string? Color { get; set; }
    public string? LicensePlate { get; set; }
    public string? Vin { get; set; }
    public string? Description { get; set; }
    public bool IsPrimary { get; set; }
    public User Owner { get; set; } = null!;
    public ICollection<MotorcycleImage> Images { get; set; } = [];
}

public sealed class MotorcycleImage : Entity
{
    public Guid MotorcycleId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string? ThumbnailUrl { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsPrimary { get; set; }
    public Motorcycle Motorcycle { get; set; } = null!;
}

public sealed class ProductCategory : SoftDeletableEntity
{
    public Guid? ParentCategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public ProductCategory? ParentCategory { get; set; }
    public ICollection<ProductCategory> Children { get; set; } = [];
    public ICollection<Product> Products { get; set; } = [];
}

public sealed class Product : SoftDeletableEntity
{
    public Guid SellerUserId { get; set; }
    public Guid CategoryId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal? Price { get; set; }
    public string? Currency { get; set; }
    public int? StockQuantity { get; set; }
    public ProductCondition Condition { get; set; }
    public ProductStatus Status { get; set; }
    public string? Location { get; set; }
    public DateTimeOffset? PublishedAt { get; set; }
    public User Seller { get; set; } = null!;
    public ProductCategory Category { get; set; } = null!;
    public ICollection<ProductImage> Images { get; set; } = [];
}

public sealed class ProductImage : Entity
{
    public Guid ProductId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string? ThumbnailUrl { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsPrimary { get; set; }
    public Product Product { get; set; } = null!;
}

public sealed class ProductFavorite
{
    public Guid UserId { get; set; }
    public Guid ProductId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public User User { get; set; } = null!;
    public Product Product { get; set; } = null!;
}

public sealed class MotorcycleFavorite
{
    public Guid UserId { get; set; }
    public Guid MotorcycleId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public User User { get; set; } = null!;
    public Motorcycle Motorcycle { get; set; } = null!;
}

public sealed class WorkshopFavorite
{
    public Guid UserId { get; set; }
    public Guid WorkshopId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public User User { get; set; } = null!;
    public Workshop Workshop { get; set; } = null!;
}

public sealed class Workshop : SoftDeletableEntity
{
    public Guid OwnerUserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Email { get; set; }
    public string? Address { get; set; }
    public string? City { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public WorkshopStatus Status { get; set; }
    public DateTimeOffset? VerifiedAt { get; set; }
    public User Owner { get; set; } = null!;
    public ICollection<WorkshopSchedule> Schedules { get; set; } = [];
    public ICollection<WorkshopService> Services { get; set; } = [];
}

public sealed class WorkshopSchedule : Entity
{
    public Guid WorkshopId { get; set; }
    public int DayOfWeek { get; set; }
    public TimeOnly? OpenTime { get; set; }
    public TimeOnly? CloseTime { get; set; }
    public bool IsClosed { get; set; }
    public Workshop Workshop { get; set; } = null!;
}

public sealed class WorkshopService : SoftDeletableEntity
{
    public Guid WorkshopId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal? Price { get; set; }
    public int? DurationMinutes { get; set; }
    public bool IsActive { get; set; } = true;
    public Workshop Workshop { get; set; } = null!;
}

public sealed class WorkshopReview : SoftDeletableEntity
{
    public Guid AuthorUserId { get; set; }
    public Guid WorkshopId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public ReviewStatus Status { get; set; }
    public User Author { get; set; } = null!;
    public Workshop Workshop { get; set; } = null!;
}

public sealed class ProductReview : SoftDeletableEntity
{
    public Guid AuthorUserId { get; set; }
    public Guid ProductId { get; set; }
    public int Rating { get; set; }
    public string? Comment { get; set; }
    public ReviewStatus Status { get; set; }
    public User Author { get; set; } = null!;
    public Product Product { get; set; } = null!;
}

public sealed class TheftReport : SoftDeletableEntity
{
    public Guid ReporterUserId { get; set; }
    public Guid? MotorcycleId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string? LicensePlate { get; set; }
    public string? Vin { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? Color { get; set; }
    public DateTimeOffset TheftDate { get; set; }
    public string? TheftLocation { get; set; }
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }
    public TheftReportStatus Status { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
    public User Reporter { get; set; } = null!;
    public Motorcycle? Motorcycle { get; set; }
    public ICollection<TheftAlertRecipient> AlertRecipients { get; set; } = [];
}

public sealed class TheftAlertRecipient
{
    public Guid TheftReportId { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset NotifiedAt { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
    public string AlertChannel { get; set; } = string.Empty;
    public TheftReport TheftReport { get; set; } = null!;
    public User User { get; set; } = null!;
}

public sealed class Notification : Entity
{
    public Guid RecipientUserId { get; set; }
    public Guid? ActorUserId { get; set; }
    public NotificationType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Body { get; set; } = string.Empty;
    public string? DataJson { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
    public DateTimeOffset? SentAt { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public User Recipient { get; set; } = null!;
    public User? Actor { get; set; }
}

public sealed class UserDevice : Entity
{
    public Guid UserId { get; set; }
    public string DeviceId { get; set; } = string.Empty;
    public string PushTokenCiphertext { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty;
    public DateTimeOffset? LastSeenAt { get; set; }
    public User User { get; set; } = null!;
}

public sealed class Conversation : SoftDeletableEntity
{
    public ConversationType Type { get; set; }
    public string? Title { get; set; }
    public DateTimeOffset? LastMessageAt { get; set; }
    public ICollection<ConversationParticipant> Participants { get; set; } = [];
    public ICollection<Message> Messages { get; set; } = [];
}

public sealed class ConversationParticipant
{
    public Guid ConversationId { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset JoinedAt { get; set; }
    public DateTimeOffset? LeftAt { get; set; }
    public DateTimeOffset? LastReadAt { get; set; }
    public bool IsMuted { get; set; }
    public Conversation Conversation { get; set; } = null!;
    public User User { get; set; } = null!;
}

public sealed class Message : SoftDeletableEntity
{
    public Guid ConversationId { get; set; }
    public Guid SenderUserId { get; set; }
    public Guid? ReplyToMessageId { get; set; }
    public string Content { get; set; } = string.Empty;
    public MessageType MessageType { get; set; }
    public DateTimeOffset SentAt { get; set; }
    public DateTimeOffset? EditedAt { get; set; }
    public Conversation Conversation { get; set; } = null!;
    public User Sender { get; set; } = null!;
    public Message? ReplyToMessage { get; set; }
    public ICollection<MessageAttachment> Attachments { get; set; } = [];
}

public sealed class MessageAttachment : Entity
{
    public Guid MessageId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long SizeBytes { get; set; }
    public Message Message { get; set; } = null!;
}

public sealed class Post : SoftDeletableEntity
{
    public Guid AuthorUserId { get; set; }
    public string? Title { get; set; }
    public string Content { get; set; } = string.Empty;
    public PostStatus Status { get; set; }
    public DateTimeOffset? PublishedAt { get; set; }
    public User Author { get; set; } = null!;
    public ICollection<PostMedia> Media { get; set; } = [];
    public ICollection<PostComment> Comments { get; set; } = [];
    public ICollection<PostLike> Likes { get; set; } = [];
}

public sealed class PostMedia : Entity
{
    public Guid PostId { get; set; }
    public string StorageKey { get; set; } = string.Empty;
    public string Url { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
    public Post Post { get; set; } = null!;
}

public sealed class PostComment : SoftDeletableEntity
{
    public Guid PostId { get; set; }
    public Guid AuthorUserId { get; set; }
    public Guid? ParentCommentId { get; set; }
    public string Content { get; set; } = string.Empty;
    public Post Post { get; set; } = null!;
    public User Author { get; set; } = null!;
    public PostComment? ParentComment { get; set; }
    public ICollection<PostComment> Replies { get; set; } = [];
}

public sealed class PostLike
{
    public Guid PostId { get; set; }
    public Guid UserId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public Post Post { get; set; } = null!;
    public User User { get; set; } = null!;
}

public sealed class News : SoftDeletableEntity
{
    public Guid? AuthorUserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public string? Summary { get; set; }
    public string Content { get; set; } = string.Empty;
    public string? FeaturedImageUrl { get; set; }
    public NewsStatus Status { get; set; }
    public DateTimeOffset? PublishedAt { get; set; }
    public User? Author { get; set; }
    public ICollection<NewsCategoryAssignment> Categories { get; set; } = [];
}

public sealed class NewsCategory : SoftDeletableEntity
{
    public string Name { get; set; } = string.Empty;
    public string Slug { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public ICollection<NewsCategoryAssignment> News { get; set; } = [];
}

public sealed class NewsCategoryAssignment
{
    public Guid NewsId { get; set; }
    public Guid NewsCategoryId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public News News { get; set; } = null!;
    public NewsCategory Category { get; set; } = null!;
}

public sealed class Referral : Entity
{
    public Guid ReferrerUserId { get; set; }
    public Guid? ReferredUserId { get; set; }
    public string Code { get; set; } = string.Empty;
    public ReferralStatus Status { get; set; }
    public DateTimeOffset? AcceptedAt { get; set; }
    public DateTimeOffset? ExpiresAt { get; set; }
    public User Referrer { get; set; } = null!;
    public User? ReferredUser { get; set; }
    public ICollection<ReferralReward> Rewards { get; set; } = [];
}

public sealed class ReferralReward : Entity
{
    public Guid ReferralId { get; set; }
    public Guid UserId { get; set; }
    public RewardType RewardType { get; set; }
    public decimal? Amount { get; set; }
    public string? Currency { get; set; }
    public RewardStatus Status { get; set; }
    public DateTimeOffset? GrantedAt { get; set; }
    public DateTimeOffset? RedeemedAt { get; set; }
    public Referral Referral { get; set; } = null!;
    public User User { get; set; } = null!;
}

public sealed class SubscriptionPlan : Entity
{
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string Currency { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public ICollection<Subscription> Subscriptions { get; set; } = [];
}

public sealed class Subscription : Entity
{
    public Guid UserId { get; set; }
    public Guid SubscriptionPlanId { get; set; }
    public SubscriptionStatus Status { get; set; }
    public SubscriptionProvider Provider { get; set; }
    public string ProviderSubscriptionId { get; set; } = string.Empty;
    public DateTimeOffset StartedAt { get; set; }
    public DateTimeOffset CurrentPeriodStart { get; set; }
    public DateTimeOffset CurrentPeriodEnd { get; set; }
    public DateTimeOffset? CanceledAt { get; set; }
    public DateTimeOffset? EndedAt { get; set; }
    public User User { get; set; } = null!;
    public SubscriptionPlan Plan { get; set; } = null!;
}

public abstract class ModerationReport : Entity
{
    public Guid ReporterUserId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string? Description { get; set; }
    public ModerationReportStatus Status { get; set; }
    public string? Resolution { get; set; }
    public Guid? ResolvedByUserId { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
    public User Reporter { get; set; } = null!;
    public User? ResolvedByUser { get; set; }
}

public sealed class UserReport : ModerationReport
{
    public Guid ReportedUserId { get; set; }
    public User ReportedUser { get; set; } = null!;
}

public sealed class PostReport : ModerationReport
{
    public Guid PostId { get; set; }
    public Post Post { get; set; } = null!;
}

public sealed class CommentReport : ModerationReport
{
    public Guid PostCommentId { get; set; }
    public PostComment PostComment { get; set; } = null!;
}

public sealed class ProductReport : ModerationReport
{
    public Guid ProductId { get; set; }
    public Product Product { get; set; } = null!;
}

public sealed class MessageReport : ModerationReport
{
    public Guid MessageId { get; set; }
    public Message Message { get; set; } = null!;
}

public sealed class AuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid? ActorUserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public Guid EntityId { get; set; }
    public string? OldValuesJson { get; set; }
    public string? NewValuesJson { get; set; }
    public string? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public string? CorrelationId { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public User? ActorUser { get; set; }
}