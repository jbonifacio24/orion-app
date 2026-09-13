namespace MotoHub.Application.Profile;

public interface IProfileService
{
    Task<ProfileResponseDto> GetCurrentAsync(Guid userId, CancellationToken cancellationToken);
    Task<ProfileResponseDto> UpdateAsync(Guid userId, UpdateProfileRequestDto request, CancellationToken cancellationToken);
}
