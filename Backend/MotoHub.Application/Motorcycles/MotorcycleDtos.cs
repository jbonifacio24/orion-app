namespace MotoHub.Application.Motorcycles;

public sealed record MotorcycleImageResponseDto(
    Guid Id,
    string Url,
    string? ThumbnailUrl,
    int DisplayOrder,
    bool IsPrimary);

public sealed record MotorcycleResponseDto(
    Guid Id,
    string Brand,
    string Model,
    int Year,
    int? Displacement,
    string? Color,
    string? LicensePlate,
    string? Vin,
    string? Description,
    bool IsPrimary,
    IReadOnlyCollection<MotorcycleImageResponseDto> Images);

public sealed record CreateMotorcycleRequestDto(
    string Brand,
    string Model,
    int Year,
    int? Displacement,
    string? Color,
    string? LicensePlate,
    string? Vin,
    string? Description,
    bool IsPrimary);

public sealed record UpdateMotorcycleRequestDto(
    string Brand,
    string Model,
    int Year,
    int? Displacement,
    string? Color,
    string? LicensePlate,
    string? Vin,
    string? Description,
    bool IsPrimary);
