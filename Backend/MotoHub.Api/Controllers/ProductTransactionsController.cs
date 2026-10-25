using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/transactions")]
public sealed class ProductTransactionsController(IProductTransactionService transactionService) : CurrentUserControllerBase
{
    [HttpPost("/api/products/{productId:guid}/transactions")]
    public async Task<IActionResult> Create(Guid productId, CreateProductTransactionRequestDto request, CancellationToken cancellationToken)
    {
        var transaction = await transactionService.CreateAsync(CurrentUserId(), productId, request, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = transaction.Id }, transaction);
    }

    [HttpGet]
    public Task<IReadOnlyCollection<ProductTransactionResponseDto>> GetMine(CancellationToken cancellationToken)
        => transactionService.GetMineAsync(CurrentUserId(), cancellationToken);

    [HttpGet("{id:guid}")]
    public Task<ProductTransactionResponseDto> GetById(Guid id, CancellationToken cancellationToken)
        => transactionService.GetByIdAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost("{id:guid}/accept")]
    public Task<ProductTransactionResponseDto> Accept(Guid id, CancellationToken cancellationToken)
        => Change(id, "accept", null, cancellationToken);

    [HttpPost("{id:guid}/paid")]
    public Task<ProductTransactionResponseDto> Paid(Guid id, CancellationToken cancellationToken)
        => Change(id, "paid", null, cancellationToken);

    [HttpPost("{id:guid}/delivered")]
    public Task<ProductTransactionResponseDto> Delivered(Guid id, CancellationToken cancellationToken)
        => Change(id, "delivered", null, cancellationToken);

    [HttpPost("{id:guid}/complete")]
    public Task<ProductTransactionResponseDto> Complete(Guid id, CancellationToken cancellationToken)
        => Change(id, "complete", null, cancellationToken);

    [HttpPost("{id:guid}/cancel")]
    public Task<ProductTransactionResponseDto> Cancel(Guid id, ChangeProductTransactionStatusRequestDto request, CancellationToken cancellationToken)
        => Change(id, "cancel", request.CancellationReason, cancellationToken);

    [HttpPost("{id:guid}/reviews")]
    public Task<ProductTransactionReviewResponseDto> AddReview(Guid id, CreateProductTransactionReviewRequestDto request, CancellationToken cancellationToken)
        => transactionService.AddReviewAsync(CurrentUserId(), id, request, cancellationToken);

    [HttpGet("{id:guid}/reviews")]
    public Task<IReadOnlyCollection<ProductTransactionReviewResponseDto>> GetReviews(Guid id, CancellationToken cancellationToken)
        => transactionService.GetReviewsAsync(CurrentUserId(), id, cancellationToken);

    [HttpGet("{id:guid}/reputation")]
    public Task<ProductTransactionReputationResponseDto> GetReputation(Guid id, CancellationToken cancellationToken)
        => transactionService.GetReputationAsync(CurrentUserId(), id, cancellationToken);

    [HttpPost("{id:guid}/delivery")]
    public Task<DeliveryResponseDto> RequestDelivery(Guid id, CreateDeliveryRequestDto request, [FromServices] IDeliveryService deliveryService, CancellationToken cancellationToken)
        => deliveryService.RequestAsync(CurrentUserId(), id, request, cancellationToken);

    [HttpGet("{id:guid}/delivery/drivers")]
    public Task<IReadOnlyCollection<NearbyDeliveryDriverResponseDto>> GetNearbyDeliveryDrivers(Guid id, [FromServices] IDeliveryService deliveryService, CancellationToken cancellationToken)
        => deliveryService.GetNearbyDriversAsync(CurrentUserId(), id, cancellationToken);

    [HttpGet("{id:guid}/delivery")]
    public Task<DeliveryResponseDto> GetDelivery(Guid id, [FromServices] IDeliveryService deliveryService, CancellationToken cancellationToken)
        => deliveryService.GetAsync(CurrentUserId(), id, cancellationToken);

    [HttpPut("{id:guid}/delivery/location")]
    public Task<DeliveryResponseDto> UpdateDeliveryLocation(Guid id, UpdateDeliveryLocationRequestDto request, [FromServices] IDeliveryService deliveryService, CancellationToken cancellationToken)
        => deliveryService.UpdateLocationAsync(CurrentUserId(), id, request, cancellationToken);

    [HttpPost("{id:guid}/delivery/complete")]
    public Task<DeliveryResponseDto> CompleteDelivery(Guid id, [FromServices] IDeliveryService deliveryService, CancellationToken cancellationToken)
        => deliveryService.MarkDeliveredAsync(CurrentUserId(), id, cancellationToken);

    private Task<ProductTransactionResponseDto> Change(Guid id, string action, string? reason, CancellationToken cancellationToken)
        => transactionService.ChangeStatusAsync(CurrentUserId(), id, action, reason, cancellationToken);
}