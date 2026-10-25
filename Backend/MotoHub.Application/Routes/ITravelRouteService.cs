namespace MotoHub.Application.Routes;

public interface ITravelRouteService
{
    Task<IReadOnlyCollection<TravelRouteResponse>> GetPublishedAsync(CancellationToken cancellationToken);
    Task<TravelRouteResponse> CreateAsync(Guid adminUserId, CreateTravelRouteRequest request, CancellationToken cancellationToken);
    Task<Guid> JoinChatAsync(Guid userId, Guid routeId, CancellationToken cancellationToken);
    Task DeleteAsync(Guid routeId, CancellationToken cancellationToken);
}
