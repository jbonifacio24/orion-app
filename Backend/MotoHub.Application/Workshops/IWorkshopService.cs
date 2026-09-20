using MotoHub.Application.Marketplace;

namespace MotoHub.Application.Workshops;

public interface IWorkshopService
{
    Task<PagedResponse<WorkshopListItemDto>> GetWorkshopsAsync(WorkshopListQueryDto query, CancellationToken cancellationToken);
    Task<WorkshopDetailResponseDto> GetWorkshopByIdAsync(Guid workshopId, CancellationToken cancellationToken);
}