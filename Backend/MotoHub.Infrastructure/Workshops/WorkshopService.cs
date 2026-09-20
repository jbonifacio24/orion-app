using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Application.Workshops;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Workshops;

public sealed class WorkshopService(MotoHubDbContext dbContext) : IWorkshopService
{
    private const int MaxPageSize = 50;
    private const int DetailReviewLimit = 20;

    public async Task<PagedResponse<WorkshopListItemDto>> GetWorkshopsAsync(
        WorkshopListQueryDto query,
        CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var search = Normalize(query.Search);
        var city = Normalize(query.City);
        var pageSize = query.PageSize;

        var workshops = dbContext.Workshops
            .AsNoTracking()
            .Where(workshop => workshop.Status == WorkshopStatus.Active);

        if (search is not null)
        {
            workshops = workshops.Where(workshop =>
                workshop.Name.Contains(search) ||
                (workshop.City != null && workshop.City.Contains(search)) ||
                (workshop.Address != null && workshop.Address.Contains(search)));
        }

        if (city is not null)
        {
            workshops = workshops.Where(workshop => workshop.City != null && workshop.City.Contains(city));
        }

        var projected = workshops.Select(workshop => new WorkshopListItemDto(
            workshop.Id,
            workshop.Name,
            workshop.Description,
            workshop.Address,
            workshop.City,
            workshop.Latitude,
            workshop.Longitude,
            dbContext.WorkshopReviews
                .Where(review => review.WorkshopId == workshop.Id)
                .Where(review => review.Status == ReviewStatus.Published)
                .Select(review => (decimal?)review.Rating)
                .Average(),
            dbContext.WorkshopReviews.Count(review => review.WorkshopId == workshop.Id && review.Status == ReviewStatus.Published)));

        var totalCount = await projected.CountAsync(cancellationToken);
        var items = await projected
            .OrderBy(workshop => workshop.Name)
            .ThenBy(workshop => workshop.Id)
            .Skip((query.Page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)pageSize);

        return new PagedResponse<WorkshopListItemDto>(items, query.Page, pageSize, totalCount, totalPages);
    }

    public async Task<WorkshopDetailResponseDto> GetWorkshopByIdAsync(
        Guid workshopId,
        CancellationToken cancellationToken)
    {
        var workshop = await dbContext.Workshops
            .AsNoTracking()
            .Where(workshop => workshop.Id == workshopId && workshop.Status == WorkshopStatus.Active)
            .Select(workshop => new
            {
                workshop.Id,
                workshop.Name,
                workshop.Description,
                workshop.PhoneNumber,
                workshop.Email,
                workshop.Address,
                workshop.City,
                workshop.Latitude,
                workshop.Longitude,
                workshop.VerifiedAt,
                Schedules = workshop.Schedules
                    .OrderBy(schedule => schedule.DayOfWeek)
                    .ThenBy(schedule => schedule.OpenTime)
                    .ThenBy(schedule => schedule.Id)
                    .Select(schedule => new WorkshopScheduleResponseDto(schedule.Id, schedule.DayOfWeek, schedule.OpenTime, schedule.CloseTime, schedule.IsClosed))
                    .ToList(),
                Services = workshop.Services
                    .Where(service => service.IsActive)
                    .OrderBy(service => service.Name)
                    .ThenBy(service => service.Id)
                    .Select(service => new WorkshopServiceResponseDto(service.Id, service.Name, service.Description, service.Price, service.DurationMinutes))
                    .ToList(),
                Reviews = dbContext.WorkshopReviews
                    .Where(review => review.WorkshopId == workshop.Id)
                    .Where(review => review.Status == ReviewStatus.Published)
                    .OrderByDescending(review => review.CreatedAt)
                    .ThenBy(review => review.Id)
                    .Take(DetailReviewLimit)
                    .Select(review => new WorkshopReviewResponseDto(review.Id, review.Rating, review.Comment, review.CreatedAt))
                    .ToList(),
                AverageRating = dbContext.WorkshopReviews
                    .Where(review => review.WorkshopId == workshop.Id)
                    .Where(review => review.Status == ReviewStatus.Published)
                    .Select(review => (decimal?)review.Rating)
                    .Average(),
                ReviewCount = dbContext.WorkshopReviews.Count(review => review.WorkshopId == workshop.Id && review.Status == ReviewStatus.Published)
            })
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("El taller no existe.");

        return new WorkshopDetailResponseDto(workshop.Id, workshop.Name, workshop.Description, workshop.PhoneNumber, workshop.Email, workshop.Address, workshop.City, workshop.Latitude, workshop.Longitude, workshop.VerifiedAt, workshop.Schedules, workshop.Services, workshop.Reviews, workshop.AverageRating, workshop.ReviewCount);
    }

    private static void ValidateQuery(WorkshopListQueryDto query)
    {
        if (query.Page < 1) throw new ValidationException("Page debe ser mayor o igual que uno.");
        if (query.PageSize < 1 || query.PageSize > MaxPageSize) throw new ValidationException($"PageSize debe estar entre uno y {MaxPageSize}.");
    }

    private static string? Normalize(string? value)
        => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}