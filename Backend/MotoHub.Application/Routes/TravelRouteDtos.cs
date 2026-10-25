namespace MotoHub.Application.Routes;

public sealed record CreateTravelRouteRequest(
    string Title,
    string? Description,
    string StartName,
    string EndName,
    decimal StartLatitude,
    decimal StartLongitude,
    decimal EndLatitude,
    decimal EndLongitude,
    string PathJson,
    DateTimeOffset DepartureAt,
    bool IsPublished = true);

public sealed record TravelRouteResponse(
    Guid Id,
    string Title,
    string? Description,
    string StartName,
    string EndName,
    decimal StartLatitude,
    decimal StartLongitude,
    decimal EndLatitude,
    decimal EndLongitude,
    string PathJson,
    DateTimeOffset DepartureAt,
    Guid ConversationId);
