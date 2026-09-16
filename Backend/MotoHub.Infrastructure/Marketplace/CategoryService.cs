using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Marketplace;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class CategoryService(MotoHubDbContext dbContext) : ICategoryService
{
    public async Task<IReadOnlyCollection<ProductCategoryResponseDto>> GetActiveAsync(CancellationToken cancellationToken)
        => await dbContext.ProductCategories
            .AsNoTracking()
            .Where(x => x.IsActive)
            .OrderBy(x => x.DisplayOrder)
            .ThenBy(x => x.Name)
            .ThenBy(x => x.Id)
            .Select(x => new ProductCategoryResponseDto(x.Id, x.ParentCategoryId, x.Name, x.Slug, x.Description, x.DisplayOrder, x.IsActive))
            .ToArrayAsync(cancellationToken);
}
