using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Routes;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Routes;

public sealed class TravelRouteService(MotoHubDbContext dbContext) : ITravelRouteService
{
    public async Task<IReadOnlyCollection<TravelRouteResponse>> GetPublishedAsync(CancellationToken cancellationToken)
        => (await dbContext.TravelRoutes.AsNoTracking().Where(x => x.IsPublished && x.DepartureAt >= DateTimeOffset.UtcNow.AddHours(-2)).OrderBy(x => x.DepartureAt).ToListAsync(cancellationToken)).Select(ToDto).ToArray();

    public async Task<TravelRouteResponse> CreateAsync(Guid adminUserId, CreateTravelRouteRequest request, CancellationToken cancellationToken)
    {
        Validate(request);
        var userExists = await dbContext.Users.AnyAsync(x => x.Id == adminUserId && x.IsActive, cancellationToken);
        if (!userExists) throw new ResourceNotFoundException("El usuario administrador no existe.");
            var conversation = new Conversation { Type = ConversationType.Group, Title = request.Title.Trim() };
        conversation.Participants.Add(new ConversationParticipant { ConversationId = conversation.Id, UserId = adminUserId, JoinedAt = DateTimeOffset.UtcNow });
        var route = new TravelRoute
        {
            CreatedByUserId = adminUserId,
            Title = request.Title.Trim(),
            Description = Normalize(request.Description),
            StartName = request.StartName.Trim(),
            EndName = request.EndName.Trim(),
            StartLatitude = request.StartLatitude,
            StartLongitude = request.StartLongitude,
            EndLatitude = request.EndLatitude,
            EndLongitude = request.EndLongitude,
            PathJson = request.PathJson,
            DepartureAt = request.DepartureAt,
            IsPublished = request.IsPublished,
            ConversationId = conversation.Id,
            Conversation = conversation
        };
        dbContext.TravelRoutes.Add(route);
        await dbContext.SaveChangesAsync(cancellationToken);
        return ToDto(route);
    }

    public async Task<Guid> JoinChatAsync(Guid userId, Guid routeId, CancellationToken cancellationToken)
    {
        var route = await dbContext.TravelRoutes.Include(x => x.Conversation).ThenInclude(x => x.Participants).SingleOrDefaultAsync(x => x.Id == routeId && x.IsPublished, cancellationToken)
            ?? throw new ResourceNotFoundException("La ruta no existe.");
        if (!route.Conversation.Participants.Any(x => x.UserId == userId && x.LeftAt == null))
        {
            route.Conversation.Participants.Add(new ConversationParticipant { ConversationId = route.ConversationId, UserId = userId, JoinedAt = DateTimeOffset.UtcNow });
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        return route.ConversationId;
    }

    public async Task DeleteAsync(Guid routeId, CancellationToken cancellationToken)
    {
        var route = await dbContext.TravelRoutes.SingleOrDefaultAsync(x => x.Id == routeId, cancellationToken)
            ?? throw new ResourceNotFoundException("La ruta de viaje no existe.");
        route.IsPublished = false;
        route.IsDeleted = true;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static void Validate(CreateTravelRouteRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title) || request.Title.Length > 200) throw new ValidationException("El título es obligatorio y debe tener como máximo 200 caracteres.");
        if (string.IsNullOrWhiteSpace(request.StartName) || string.IsNullOrWhiteSpace(request.EndName)) throw new ValidationException("El origen y el destino son obligatorios.");
        if (request.StartLatitude is < -90 or > 90 || request.EndLatitude is < -90 or > 90 || request.StartLongitude is < -180 or > 180 || request.EndLongitude is < -180 or > 180) throw new ValidationException("Las coordenadas de la ruta no son válidas.");
        try { using var document = JsonDocument.Parse(request.PathJson); if (document.RootElement.ValueKind != JsonValueKind.Array) throw new Exception(); }
        catch { throw new ValidationException("PathJson debe ser un arreglo JSON de coordenadas."); }
    }

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    private static TravelRouteResponse ToDto(TravelRoute route) => new(route.Id, route.Title, route.Description, route.StartName, route.EndName, route.StartLatitude, route.StartLongitude, route.EndLatitude, route.EndLongitude, route.PathJson, route.DepartureAt, route.ConversationId);
}
