using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class DeliveryService(MotoHubDbContext dbContext, IDeliveryRealtimeNotifier? realtimeNotifier = null) : IDeliveryService
{
    private const double SearchRadiusInKm = 15;
    private static readonly TimeSpan DriverLocationFreshness = TimeSpan.FromMinutes(2);

    public async Task<DeliveryDriverAvailabilityResponseDto> GetDriverAvailabilityAsync(Guid driverUserId, CancellationToken cancellationToken)
    {
        var profile = await dbContext.DeliveryDriverProfiles.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == driverUserId, cancellationToken);
        return profile is null
            ? new DeliveryDriverAvailabilityResponseDto(false, DateTimeOffset.UtcNow)
            : new DeliveryDriverAvailabilityResponseDto(profile.IsAvailable, profile.UpdatedAt);
    }

    public async Task<DeliveryDriverEligibilityResponseDto> GetDriverEligibilityAsync(Guid driverUserId, CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == driverUserId, cancellationToken)
            ?? throw new ResourceNotFoundException("El perfil no existe.");
        var hasFullName = !string.IsNullOrWhiteSpace(user.FirstName) && !string.IsNullOrWhiteSpace(user.LastName);
        var hasPhoneNumber = !string.IsNullOrWhiteSpace(user.PhoneNumber);
        var hasQualifiedMotorcycle = await dbContext.Motorcycles.AsNoTracking().AnyAsync(motorcycle =>
            motorcycle.OwnerUserId == driverUserId &&
            !string.IsNullOrWhiteSpace(motorcycle.Brand) &&
            !string.IsNullOrWhiteSpace(motorcycle.Model) &&
            motorcycle.Year > 0 &&
            !string.IsNullOrWhiteSpace(motorcycle.LicensePlate) &&
            !string.IsNullOrWhiteSpace(motorcycle.Vin), cancellationToken);
        return new DeliveryDriverEligibilityResponseDto(user.EmailConfirmed && hasFullName && hasPhoneNumber && hasQualifiedMotorcycle, user.EmailConfirmed, hasFullName, hasPhoneNumber, hasQualifiedMotorcycle);
    }

    public async Task<DeliveryDriverAvailabilityResponseDto> UpdateDriverAvailabilityAsync(Guid driverUserId, UpdateDeliveryDriverAvailabilityRequestDto request, CancellationToken cancellationToken)
    {
        if (request.IsAvailable)
        {
            var eligibility = await GetDriverEligibilityAsync(driverUserId, cancellationToken);
            if (!eligibility.IsEligible)
                throw new ConflictException("Completa la validación de correo, nombre, apellidos, teléfono y los datos de tu motocicleta antes de ofrecerte como conductor.");
            if (request.Latitude is null || request.Longitude is null)
                throw new ValidationException("Se necesitan coordenadas para activar la disponibilidad.");
            ValidateCoordinates(request.Latitude.Value, request.Longitude.Value);
            if (await dbContext.Deliveries.AnyAsync(x => x.DriverUserId == driverUserId && x.Status != DeliveryStatus.Delivered && x.Status != DeliveryStatus.Cancelled, cancellationToken))
                throw new ConflictException("No puedes activar la disponibilidad mientras tengas un Delivery asignado.");
        }

        var profile = await dbContext.DeliveryDriverProfiles.SingleOrDefaultAsync(x => x.UserId == driverUserId, cancellationToken);
        if (profile is null)
        {
            profile = new DeliveryDriverProfile { UserId = driverUserId, Latitude = request.Latitude ?? 0, Longitude = request.Longitude ?? 0 };
            dbContext.DeliveryDriverProfiles.Add(profile);
        }
        if (request.Latitude.HasValue) profile.Latitude = request.Latitude.Value;
        if (request.Longitude.HasValue) profile.Longitude = request.Longitude.Value;
        profile.IsAvailable = request.IsAvailable;
        await dbContext.SaveChangesAsync(cancellationToken);
        return new DeliveryDriverAvailabilityResponseDto(profile.IsAvailable, profile.UpdatedAt);
    }

    public async Task<IReadOnlyCollection<NearbyDeliveryDriverResponseDto>> GetNearbyDriversAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
    {
        var transaction = await GetPaidTransactionAsync(userId, transactionId, cancellationToken);
        var product = transaction.Product;
        if (product.Latitude is null || product.Longitude is null)
            throw new ValidationException("El producto necesita una ubicación de recojo para buscar conductores cercanos.");

        var cutoff = DateTimeOffset.UtcNow - DriverLocationFreshness;
        var candidates = await dbContext.DeliveryDriverProfiles
            .AsNoTracking()
            .Where(profile => profile.IsAvailable && profile.UpdatedAt >= cutoff &&
                profile.UserId != transaction.BuyerUserId && profile.UserId != transaction.SellerUserId &&
                !dbContext.Deliveries.Any(delivery => delivery.DriverUserId == profile.UserId && delivery.Status != DeliveryStatus.Delivered && delivery.Status != DeliveryStatus.Cancelled))
            .Select(profile => new { profile.UserId, profile.User.UserName, profile.User.FirstName, profile.User.LastName, profile.Latitude, profile.Longitude })
            .ToListAsync(cancellationToken);

        return candidates
            .Select(profile => new
            {
                profile.UserId,
                DisplayName = string.Join(" ", new[] { profile.FirstName, profile.LastName }.Where(name => !string.IsNullOrWhiteSpace(name))).Trim() is { Length: > 0 } fullName ? fullName : profile.UserName,
                Distance = DistanceInKm(product.Latitude.Value, product.Longitude.Value, profile.Latitude, profile.Longitude)
            })
            .Where(profile => profile.Distance <= SearchRadiusInKm)
            .OrderBy(profile => profile.Distance)
            .Select(profile => new NearbyDeliveryDriverResponseDto(profile.UserId, profile.DisplayName, (decimal)Math.Round(profile.Distance, 1)))
            .ToArray();
    }

    public async Task<IReadOnlyCollection<DeliveryResponseDto>> GetAssignedAsync(Guid driverUserId, CancellationToken cancellationToken)
        => (await dbContext.Deliveries.AsNoTracking()
            .Where(x => x.DriverUserId == driverUserId && x.Status != DeliveryStatus.Delivered && x.Status != DeliveryStatus.Cancelled)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync(cancellationToken)).Select(ToDto).ToArray();

    public async Task<DeliveryResponseDto> RequestAsync(Guid userId, Guid transactionId, CreateDeliveryRequestDto request, CancellationToken cancellationToken)
    {
        ValidateCoordinates(request.DestinationLatitude, request.DestinationLongitude);
        var transaction = await GetPaidTransactionAsync(userId, transactionId, cancellationToken);
        if (await dbContext.Deliveries.AnyAsync(x => x.ProductTransactionId == transactionId, cancellationToken))
            throw new ConflictException("Esta operación ya tiene un Delivery.");
        var product = transaction.Product;
        if (product.Latitude is null || product.Longitude is null)
            throw new ValidationException("El producto necesita una ubicación de recojo para solicitar Delivery.");

        var profile = await dbContext.DeliveryDriverProfiles.SingleOrDefaultAsync(x => x.UserId == request.DriverUserId, cancellationToken)
            ?? throw new ResourceNotFoundException("El conductor no tiene un perfil de disponibilidad.");
        var distance = DistanceInKm(product.Latitude.Value, product.Longitude.Value, profile.Latitude, profile.Longitude);
        if (!profile.IsAvailable || profile.UpdatedAt < DateTimeOffset.UtcNow - DriverLocationFreshness || distance > SearchRadiusInKm)
            throw new ConflictException("El conductor ya no está disponible cerca del punto de recojo.");
        if (request.DriverUserId == transaction.BuyerUserId || request.DriverUserId == transaction.SellerUserId)
            throw new ValidationException("El comprador o vendedor no pueden asignarse como conductor.");

        var delivery = new Delivery
        {
            ProductTransactionId = transactionId,
            BuyerUserId = transaction.BuyerUserId,
            SellerUserId = transaction.SellerUserId,
            DriverUserId = request.DriverUserId,
            PickupLatitude = product.Latitude,
            PickupLongitude = product.Longitude,
            DestinationLatitude = request.DestinationLatitude,
            DestinationLongitude = request.DestinationLongitude,
            DriverLatitude = profile.Latitude,
            DriverLongitude = profile.Longitude
        };
        profile.IsAvailable = false;
        dbContext.Deliveries.Add(delivery);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("El conductor acaba de aceptar otra entrega.");
        }
        return await NotifyUpdatedAsync(delivery, cancellationToken);
    }

    public async Task<DeliveryResponseDto> GetAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
        => ToDto(await ParticipantDeliveryAsync(userId, transactionId, cancellationToken));

    public async Task<DeliveryResponseDto> UpdateLocationAsync(Guid driverUserId, Guid transactionId, UpdateDeliveryLocationRequestDto request, CancellationToken cancellationToken)
    {
        ValidateCoordinates(request.Latitude, request.Longitude);
        var delivery = await ParticipantDeliveryAsync(driverUserId, transactionId, cancellationToken);
        if (delivery.DriverUserId != driverUserId) throw new UnauthorizedAccessException("Solo el conductor asignado puede actualizar su ubicación.");
        delivery.DriverLatitude = request.Latitude;
        delivery.DriverLongitude = request.Longitude;
        delivery.Status = DistanceInKm(request.Latitude, request.Longitude, delivery.DestinationLatitude, delivery.DestinationLongitude) <= 0.5d ? DeliveryStatus.Near : DeliveryStatus.InTransit;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await NotifyUpdatedAsync(delivery, cancellationToken);
    }

    public async Task<DeliveryResponseDto> MarkDeliveredAsync(Guid driverUserId, Guid transactionId, CancellationToken cancellationToken)
    {
        var delivery = await ParticipantDeliveryAsync(driverUserId, transactionId, cancellationToken);
        if (delivery.DriverUserId != driverUserId) throw new UnauthorizedAccessException("Solo el conductor asignado puede finalizar el Delivery.");
        delivery.Status = DeliveryStatus.Delivered;
        await dbContext.SaveChangesAsync(cancellationToken);
        return await NotifyUpdatedAsync(delivery, cancellationToken);
    }

    private async Task<Delivery> ParticipantDeliveryAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
        => await dbContext.Deliveries.SingleOrDefaultAsync(x => x.ProductTransactionId == transactionId && (x.BuyerUserId == userId || x.SellerUserId == userId || x.DriverUserId == userId), cancellationToken)
            ?? throw new ResourceNotFoundException("El Delivery no existe.");

    private async Task<ProductTransaction> GetPaidTransactionAsync(Guid userId, Guid transactionId, CancellationToken cancellationToken)
        => await dbContext.ProductTransactions.Include(x => x.Product)
            .SingleOrDefaultAsync(x => x.Id == transactionId && (x.BuyerUserId == userId || x.SellerUserId == userId), cancellationToken) is { } transaction
            ? transaction.Status == ProductTransactionStatus.Paid
                ? transaction
                : throw new ConflictException("El Delivery solo puede solicitarse después del pago.")
            : throw new ResourceNotFoundException("La operación no existe.");

    private static void ValidateCoordinates(decimal latitude, decimal longitude)
    {
        if (latitude is < -90 or > 90 || longitude is < -180 or > 180) throw new ValidationException("Las coordenadas no son válidas.");
    }

    private static double DistanceInKm(decimal latitude1, decimal longitude1, decimal latitude2, decimal longitude2)
    {
        static double Radians(decimal value) => (double)value * Math.PI / 180d;
        var dLat = Radians(latitude2 - latitude1);
        var dLon = Radians(longitude2 - longitude1);
        var a = Math.Pow(Math.Sin(dLat / 2), 2) + Math.Cos(Radians(latitude1)) * Math.Cos(Radians(latitude2)) * Math.Pow(Math.Sin(dLon / 2), 2);
        return 6371d * 2d * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
    }

    private async Task<DeliveryResponseDto> NotifyUpdatedAsync(Delivery delivery, CancellationToken cancellationToken)
    {
        var response = ToDto(delivery);
        if (realtimeNotifier is not null)
        {
            await realtimeNotifier.NotifyDeliveryUpdatedAsync(response, cancellationToken);
        }
        return response;
    }

    private static DeliveryResponseDto ToDto(Delivery delivery) => new(delivery.Id, delivery.ProductTransactionId, delivery.SellerUserId, delivery.DriverUserId, delivery.PickupLatitude, delivery.PickupLongitude, delivery.DestinationLatitude, delivery.DestinationLongitude, delivery.DriverLatitude, delivery.DriverLongitude, delivery.Status);
}
