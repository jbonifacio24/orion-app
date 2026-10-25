namespace MotoHub.Application.Marketplace;

public interface IProductTransactionService
{
    Task<ProductTransactionResponseDto> CreateAsync(Guid buyerUserId, Guid productId, CreateProductTransactionRequestDto request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<ProductTransactionResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken);
    Task<ProductTransactionResponseDto> GetByIdAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken);
    Task<ProductTransactionResponseDto> ChangeStatusAsync(Guid userId, Guid transactionId, string action, string? cancellationReason, CancellationToken cancellationToken);
    Task<ProductTransactionReviewResponseDto> AddReviewAsync(Guid userId, Guid transactionId, CreateProductTransactionReviewRequestDto request, CancellationToken cancellationToken);
    Task<IReadOnlyCollection<ProductTransactionReviewResponseDto>> GetReviewsAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken);
    Task<ProductTransactionReputationResponseDto> GetReputationAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken);
}