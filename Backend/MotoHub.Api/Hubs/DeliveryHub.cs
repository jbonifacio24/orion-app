using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using MotoHub.Application.Marketplace;

namespace MotoHub.Api.Hubs;

[Authorize]
public sealed class DeliveryHub(IDeliveryService deliveryService) : Hub
{
    public async Task JoinDelivery(Guid transactionId)
    {
        var delivery = await deliveryService.GetAsync(CurrentUserId(), transactionId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, DeliveryGroupNames.Transaction(transactionId));
        await Clients.Caller.SendAsync("DeliveryUpdated", delivery, Context.ConnectionAborted);
    }

    public async Task LeaveDelivery(Guid transactionId)
    {
        await deliveryService.GetAsync(CurrentUserId(), transactionId, Context.ConnectionAborted);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, DeliveryGroupNames.Transaction(transactionId));
    }

    private Guid CurrentUserId()
    {
        var value = Context.User?.FindFirstValue(ClaimTypes.NameIdentifier) ??
                    Context.User?.FindFirstValue(JwtRegisteredClaimNames.Sub);
        return Guid.TryParse(value, out var userId)
            ? userId
            : throw new HubException("The authenticated user identity is invalid.");
    }
}