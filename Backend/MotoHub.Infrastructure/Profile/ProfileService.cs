using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Profile;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Profile;

public sealed class ProfileService(MotoHubDbContext dbContext) : IProfileService
{
    public async Task<ProfileResponseDto> GetCurrentAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await dbContext.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("El perfil no existe.");
        return Map(user);
    }

    public async Task<ProfileResponseDto> UpdateAsync(
        Guid userId,
        UpdateProfileRequestDto request,
        CancellationToken cancellationToken)
    {
        Validate(request);
        var user = await dbContext.Users.SingleOrDefaultAsync(x => x.Id == userId, cancellationToken)
            ?? throw new ResourceNotFoundException("El perfil no existe.");

        user.FirstName = NormalizeOptional(request.FirstName);
        user.LastName = NormalizeOptional(request.LastName);
        user.PhoneNumber = NormalizeOptional(request.PhoneNumber);
        user.Bio = NormalizeOptional(request.Bio);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Map(user);
    }

    private static void Validate(UpdateProfileRequestDto request)
    {
        ValidateLength(request.FirstName, 100, nameof(request.FirstName));
        ValidateLength(request.LastName, 100, nameof(request.LastName));
        ValidateLength(request.PhoneNumber, 30, nameof(request.PhoneNumber));
        ValidateLength(request.Bio, 2000, nameof(request.Bio));
    }

    private static void ValidateLength(string? value, int maxLength, string fieldName)
    {
        if (value is not null && value.Length > maxLength)
        {
            throw new ValidationException($"{fieldName} no puede superar {maxLength} caracteres.");
        }
    }

    private static string? NormalizeOptional(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static ProfileResponseDto Map(Domain.User user) => new(
        user.Id,
        user.UserName,
        user.Email,
        user.FirstName,
        user.LastName,
        user.PhoneNumber,
        user.ProfileImageUrl,
        user.Bio,
        user.EmailConfirmed,
        user.LastLoginAt);
}
