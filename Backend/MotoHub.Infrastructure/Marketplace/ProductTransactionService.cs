using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class ProductTransactionService(MotoHubDbContext dbContext) : IProductTransactionService
{
    private static readonly JsonSerializerOptions NotificationDataOptions = new(JsonSerializerDefaults.Web);

    public async Task<ProductTransactionResponseDto> CreateAsync(Guid buyerUserId, Guid productId, CreateProductTransactionRequestDto request, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products.SingleOrDefaultAsync(x => x.Id == productId && x.Status == ProductStatus.Active && x.Category.IsActive, cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe o no está activo.");
        if (product.SellerUserId == buyerUserId) throw new ValidationException("El comprador no puede ser el vendedor.");
        if (request.OfferedAmount <= 0 || decimal.Round(request.OfferedAmount, 2) != request.OfferedAmount) throw new ValidationException("OfferedAmount debe ser mayor que cero y tener como máximo dos decimales.");
        var currency = request.Currency?.Trim().ToUpperInvariant();
        if (string.IsNullOrWhiteSpace(currency) || currency.Length != 3 || currency.Any(x => !char.IsLetter(x))) throw new ValidationException("Currency debe tener tres letras.");
        var paymentMethod = request.PaymentMethod?.Trim();
        if (string.IsNullOrWhiteSpace(paymentMethod) || paymentMethod.Length > 50) throw new ValidationException("PaymentMethod es obligatorio y debe tener como máximo 50 caracteres.");

        var transaction = new ProductTransaction { ProductId = product.Id, SellerUserId = product.SellerUserId, BuyerUserId = buyerUserId, OfferedAmount = request.OfferedAmount, Currency = currency, PaymentMethod = paymentMethod, Status = ProductTransactionStatus.Offer };
        dbContext.ProductTransactions.Add(transaction);
        dbContext.Notifications.Add(CreateMarketplaceNotification(
            product.SellerUserId,
            buyerUserId,
            product.Id,
            "Nueva oferta recibida",
            $"Recibiste una oferta por {product.Name}: {request.OfferedAmount:0.00} {currency}."));
        await SaveAsync(cancellationToken);
        return ToDto(transaction);
    }

    public async Task<IReadOnlyCollection<ProductTransactionResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken)
        => (await dbContext.ProductTransactions.AsNoTracking().Where(x => x.BuyerUserId == userId || x.SellerUserId == userId).OrderByDescending(x => x.CreatedAt).ThenByDescending(x => x.Id).ToListAsync(cancellationToken)).Select(ToDto).ToArray();

    public async Task<ProductTransactionResponseDto> GetByIdAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
        => ToDto(await GetParticipantTransactionAsync(userId, transactionId, cancellationToken));

    public async Task<ProductTransactionResponseDto> ChangeStatusAsync(Guid userId, Guid transactionId, string action, string? cancellationReason, CancellationToken cancellationToken)
    {
        var transaction = await GetParticipantTransactionAsync(userId, transactionId, cancellationToken, includeProduct: true);
        var target = action.Trim().ToLowerInvariant() switch
        {
            "accept" => ProductTransactionStatus.Accepted,
            "paid" => ProductTransactionStatus.Paid,
            "delivered" => ProductTransactionStatus.Delivered,
            "complete" => ProductTransactionStatus.Completed,
            "cancel" => ProductTransactionStatus.Cancelled,
            _ => throw new ValidationException("La acción de transacción no es válida.")
        };
        if (target == ProductTransactionStatus.Accepted && (transaction.SellerUserId != userId || transaction.Status != ProductTransactionStatus.Offer)) throw new ConflictException("Solo el vendedor puede aceptar una oferta pendiente.");
        if (target == ProductTransactionStatus.Paid && (transaction.BuyerUserId != userId || transaction.Status != ProductTransactionStatus.Accepted)) throw new ConflictException("Solo el comprador puede marcar como pagada una oferta aceptada.");
        if (target == ProductTransactionStatus.Delivered && (transaction.SellerUserId != userId || transaction.Status != ProductTransactionStatus.Paid)) throw new ConflictException("Solo el vendedor puede marcar como entregada una oferta pagada.");
        if (target == ProductTransactionStatus.Completed && (transaction.Status != ProductTransactionStatus.Delivered || (userId != transaction.BuyerUserId && userId != transaction.SellerUserId))) throw new ConflictException("La transacción solo puede completarse después de la entrega.");
        if (target == ProductTransactionStatus.Cancelled)
        {
            if (transaction.Status is ProductTransactionStatus.Completed or ProductTransactionStatus.Cancelled) throw new ConflictException("La transacción ya no puede cancelarse.");
            if (string.IsNullOrWhiteSpace(cancellationReason) || cancellationReason.Trim().Length > 1000) throw new ValidationException("CancellationReason es obligatorio y debe tener como máximo 1000 caracteres.");
            transaction.CancellationReason = cancellationReason.Trim();
            transaction.CancelledAt = DateTimeOffset.UtcNow;
        }
        transaction.Status = target;
        var now = DateTimeOffset.UtcNow;
        if (target == ProductTransactionStatus.Accepted) transaction.AcceptedAt = now;
        if (target == ProductTransactionStatus.Paid) transaction.PaidAt = now;
        if (target == ProductTransactionStatus.Delivered) transaction.DeliveredAt = now;
        if (target == ProductTransactionStatus.Completed)
        {
            transaction.CompletedAt = now;
            transaction.Product.Status = ProductStatus.Sold;
            transaction.Product.StockQuantity = 0;
        }
        var notification = target switch
        {
            ProductTransactionStatus.Accepted => CreateMarketplaceNotification(
                transaction.BuyerUserId,
                userId,
                transaction.ProductId,
                "Oferta aceptada",
                $"El vendedor aceptó tu oferta por {transaction.Product.Name}."),
            ProductTransactionStatus.Paid => CreateMarketplaceNotification(
                transaction.SellerUserId,
                userId,
                transaction.ProductId,
                "Pago marcado como realizado",
                $"El comprador marcó como pagada la oferta por {transaction.Product.Name}."),
            _ => null
        };
        if (notification is not null) dbContext.Notifications.Add(notification);
        await SaveAsync(cancellationToken);
        return ToDto(transaction);
    }

    public async Task<ProductTransactionReviewResponseDto> AddReviewAsync(Guid userId, Guid transactionId, CreateProductTransactionReviewRequestDto request, CancellationToken cancellationToken)
    {
        var transaction = await GetParticipantTransactionAsync(userId, transactionId, cancellationToken);
        if (transaction.Status != ProductTransactionStatus.Completed) throw new ConflictException("Solo se pueden reseñar transacciones completadas.");
        if (request.Rating is < 1 or > 5) throw new ValidationException("Rating debe estar entre 1 y 5.");
        var reviewedUserId = transaction.SellerUserId == userId ? transaction.BuyerUserId : transaction.SellerUserId;
        var comment = string.IsNullOrWhiteSpace(request.Comment) ? null : request.Comment.Trim();
        if (comment?.Length > 2000) throw new ValidationException("Comment no puede superar 2000 caracteres.");
        if (await dbContext.ProductTransactionReviews.AnyAsync(x => x.ProductTransactionId == transactionId && x.ReviewerUserId == userId, cancellationToken)) throw new ConflictException("Ya existe una reseña de este participante.");
        var review = new ProductTransactionReview { ProductTransactionId = transactionId, ReviewerUserId = userId, ReviewedUserId = reviewedUserId, Rating = request.Rating, Comment = comment };
        dbContext.ProductTransactionReviews.Add(review);
        await SaveAsync(cancellationToken);
        return ToReviewDto(review);
    }

    public async Task<IReadOnlyCollection<ProductTransactionReviewResponseDto>> GetReviewsAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
    {
        await GetParticipantTransactionAsync(userId, transactionId, cancellationToken);
        return (await dbContext.ProductTransactionReviews.AsNoTracking().Where(x => x.ProductTransactionId == transactionId).OrderBy(x => x.CreatedAt).ToListAsync(cancellationToken)).Select(ToReviewDto).ToArray();
    }

    public async Task<ProductTransactionReputationResponseDto> GetReputationAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
    {
        var transaction = await GetParticipantTransactionAsync(userId, transactionId, cancellationToken);
        var participantIds = new[] { transaction.BuyerUserId, transaction.SellerUserId };
        var ratings = await dbContext.ProductTransactionReviews.AsNoTracking()
            .Where(review => participantIds.Contains(review.ReviewedUserId))
            .GroupBy(review => review.ReviewedUserId)
            .Select(group => new { UserId = group.Key, AverageRating = group.Average(review => (decimal)review.Rating), RatingCount = group.Count() })
            .ToDictionaryAsync(group => group.UserId, cancellationToken);
        var sales = await dbContext.ProductTransactions.AsNoTracking()
            .Where(item => item.Status == ProductTransactionStatus.Completed && participantIds.Contains(item.SellerUserId))
            .GroupBy(item => item.SellerUserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(group => group.UserId, group => group.Count, cancellationToken);
        var purchases = await dbContext.ProductTransactions.AsNoTracking()
            .Where(item => item.Status == ProductTransactionStatus.Completed && participantIds.Contains(item.BuyerUserId))
            .GroupBy(item => item.BuyerUserId)
            .Select(group => new { UserId = group.Key, Count = group.Count() })
            .ToDictionaryAsync(group => group.UserId, group => group.Count, cancellationToken);

        ParticipantReputationDto ForUser(Guid participantId)
        {
            ratings.TryGetValue(participantId, out var rating);
            return new ParticipantReputationDto(participantId, rating?.AverageRating ?? 0, rating?.RatingCount ?? 0, sales.GetValueOrDefault(participantId), purchases.GetValueOrDefault(participantId));
        }

        return new ProductTransactionReputationResponseDto(ForUser(transaction.BuyerUserId), ForUser(transaction.SellerUserId));
    }

    private async Task<ProductTransaction> GetParticipantTransactionAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken, bool includeProduct = false)
    {
        IQueryable<ProductTransaction> query = dbContext.ProductTransactions;
        if (includeProduct) query = query.Include(x => x.Product);
        return await query.SingleOrDefaultAsync(x => x.Id == transactionId && (x.BuyerUserId == userId || x.SellerUserId == userId), cancellationToken)
            ?? throw new ResourceNotFoundException("La transacción no existe.");
    }

    private static Notification CreateMarketplaceNotification(
        Guid recipientUserId,
        Guid actorUserId,
        Guid productId,
        string title,
        string body)
        => new()
        {
            RecipientUserId = recipientUserId,
            ActorUserId = actorUserId,
            Type = NotificationType.Marketplace,
            Title = title,
            Body = body,
            DataJson = JsonSerializer.Serialize(
                new { resourceType = "Product", resourceId = productId },
                NotificationDataOptions)
        };

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        try { await dbContext.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateConcurrencyException) { throw new ConflictException("La transacción fue modificada por otro usuario."); }
    }

    private static ProductTransactionResponseDto ToDto(ProductTransaction x) => new(x.Id, x.ProductId, x.SellerUserId, x.BuyerUserId, x.OfferedAmount, x.Currency, x.PaymentMethod, x.Status, x.CreatedAt, x.UpdatedAt, x.AcceptedAt, x.PaidAt, x.DeliveredAt, x.CompletedAt, x.CancelledAt, x.CancellationReason, Convert.ToBase64String(x.RowVersion));
    private static ProductTransactionReviewResponseDto ToReviewDto(ProductTransactionReview x) => new(x.Id, x.ProductTransactionId, x.ReviewerUserId, x.ReviewedUserId, x.Rating, x.Comment, x.CreatedAt);
}