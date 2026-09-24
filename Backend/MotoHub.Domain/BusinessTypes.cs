namespace MotoHub.Domain;

public enum ProductCondition
{
    New,
    Used
}

public enum ProductStatus
{
    Draft,
    Active,
    Sold,
    Archived
}

public enum WorkshopStatus
{
    Pending,
    Active,
    Suspended,
    Archived
}

public enum ReviewStatus
{
    Pending,
    Published,
    Rejected,
    Hidden
}

public enum TheftReportStatus
{
    Reported,
    Investigating,
    Recovered,
    Closed
}

public enum NotificationType
{
    System,
    Security,
    Message,
    Social,
    Marketplace,
    Theft
}

public enum ConversationType
{
    Direct,
    Group,
    Marketplace
}

public enum MessageType
{
    Text,
    Image,
    File,
    System
}

public enum PostStatus
{
    Draft,
    Published,
    Archived,
    Removed
}

public enum NewsStatus
{
    Draft,
    Published,
    Archived
}

public enum ReferralStatus
{
    Pending,
    Accepted,
    Expired,
    Cancelled
}

public enum RewardType
{
    Credit,
    Discount,
    VipDays
}

public enum RewardStatus
{
    Pending,
    Granted,
    Redeemed,
    Expired
}

public enum SubscriptionStatus
{
    Pending,
    Active,
    Cancelled,
    Expired
}

public enum SubscriptionProvider
{
    Stripe,
    Paypal,
    Manual
}

public enum ModerationReportStatus
{
    Pending,
    Reviewing,
    Resolved,
    Rejected
}