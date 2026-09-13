namespace MotoHub.Application.Motorcycles;

public interface IMotorcycleService
{
    Task<IReadOnlyCollection<MotorcycleResponseDto>> GetMineAsync(Guid userId, CancellationToken cancellationToken);
    Task<MotorcycleResponseDto> GetByIdAsync(Guid userId, Guid motorcycleId, CancellationToken cancellationToken);
    Task<MotorcycleResponseDto> CreateAsync(Guid userId, CreateMotorcycleRequestDto request, CancellationToken cancellationToken);
    Task<MotorcycleResponseDto> UpdateAsync(Guid userId, Guid motorcycleId, UpdateMotorcycleRequestDto request, CancellationToken cancellationToken);
    Task DeleteAsync(Guid userId, Guid motorcycleId, CancellationToken cancellationToken);
}
