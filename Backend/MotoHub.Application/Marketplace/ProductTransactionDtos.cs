using MotoHub.Domain;

namespace MotoHub.Application.Marketplace;

public sealed record CreateProductTransactionRequestDto(
    decimal OfferedAmount,
    string Currency,
    string PaymentMethod);

public sealed record ChangeProductTransactionStatusRequestDto(string? CancellationReason = null);

public sealed record ProductTransactionResponseDto(
    Guid Id,
    Guid ProductId,
    Guid SellerUserId,
    Guid BuyerUserId,
    decimal OfferedAmount,
    string Currency,
    string PaymentMethod,
    ProductTransactionStatus Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? AcceptedAt,
    DateTimeOffset? PaidAt,
    DateTimeOffset? DeliveredAt,
    DateTimeOffset? CompletedAt,
    DateTimeOffset? CancelledAt,
    string? CancellationReason,
    string RowVersion);

public sealed record CreateProductTransactionReviewRequestDto(int Rating, string? Comment);

public sealed record ProductTransactionReviewResponseDto(
    Guid Id,
    Guid ProductTransactionId,
    Guid ReviewerUserId,
    Guid ReviewedUserId,
    int Rating,
    string? Comment,
    DateTimeOffset CreatedAt);

public sealed record ParticipantReputationDto(
    Guid UserId,
    decimal AverageRating,
    int RatingCount,
    int SuccessfulSales,
    int SuccessfulPurchases);

public sealed record ProductTransactionReputationResponseDto(
    ParticipantReputationDto Buyer,
    ParticipantReputationDto Seller);
