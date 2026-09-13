namespace MotoHub.Application.Profile;

public sealed record ProfileResponseDto(
    Guid Id,
    string UserName,
    string Email,
    string? FirstName,
    string? LastName,
    string? PhoneNumber,
    string? ProfileImageUrl,
    string? Bio,
    bool EmailConfirmed,
    DateTimeOffset? LastLoginAt);

public sealed record UpdateProfileRequestDto(
    string? FirstName,
    string? LastName,
    string? PhoneNumber,
    string? Bio);
