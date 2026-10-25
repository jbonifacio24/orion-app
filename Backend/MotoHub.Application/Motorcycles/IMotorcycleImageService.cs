namespace MotoHub.Application.Motorcycles;

public interface IMotorcycleImageService
{
    Task<MotorcycleImageResponseDto> UploadAsync(Guid userId, Guid motorcycleId, UploadMotorcycleImageRequest request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid motorcycleId, Guid imageId, CancellationToken cancellationToken);
}