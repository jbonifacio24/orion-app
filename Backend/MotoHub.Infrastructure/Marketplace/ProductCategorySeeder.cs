using Microsoft.EntityFrameworkCore;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class ProductCategorySeeder(MotoHubDbContext dbContext)
{
    private static readonly (Guid Id, string Name, string Slug, int DisplayOrder)[] Categories =
    [
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000001"), "Motos y vehículos", "motos-y-vehiculos", 10),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000002"), "Repuestos", "repuestos", 20),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000003"), "Accesorios", "accesorios", 30),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000004"), "Cascos y protección", "cascos-y-proteccion", 40),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000005"), "Ropa para motociclista", "ropa-para-motociclista", 50),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000006"), "Herramientas", "herramientas", 60),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000007"), "Electrónica", "electronica", 70),
        (Guid.Parse("3f5d8f0a-0e66-4d4d-9e6d-000000000008"), "Otros", "otros", 80)
    ];

    public async Task SeedAsync(CancellationToken cancellationToken)
    {
        var slugs = Categories.Select(x => x.Slug).ToArray();
        var existing = await dbContext.ProductCategories
            .IgnoreQueryFilters()
            .Where(x => slugs.Contains(x.Slug))
            .Select(x => x.Slug)
            .ToListAsync(cancellationToken);
        var existingSlugs = existing.ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var category in Categories)
        {
            if (existingSlugs.Contains(category.Slug)) continue;
            var entity = new ProductCategory
            {
                Name = category.Name,
                Slug = category.Slug,
                DisplayOrder = category.DisplayOrder,
                IsActive = true
            };
            dbContext.ProductCategories.Add(entity);
            dbContext.Entry(entity).Property(nameof(Entity.Id)).CurrentValue = category.Id;
        }
        if (dbContext.ChangeTracker.HasChanges()) await dbContext.SaveChangesAsync(cancellationToken);
    }
}
