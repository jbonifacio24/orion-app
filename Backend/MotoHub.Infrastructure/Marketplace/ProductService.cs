using Microsoft.EntityFrameworkCore;
using MotoHub.Application.Errors;
using MotoHub.Application.Marketplace;
using MotoHub.Domain;
using MotoHub.Infrastructure.Persistence;

namespace MotoHub.Infrastructure.Marketplace;

public sealed class ProductService(MotoHubDbContext dbContext) : IProductService
{
    private const int DefaultPageSize = 20;
    private const int MaxPageSize = 50;

    public async Task<PagedResponse<ProductResponseDto>> GetActiveAsync(ProductListQueryDto query, Guid userId, CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var products = ApplyFilters(dbContext.Products.AsNoTracking().Include(x => x.Images).Include(x => x.Category), query, activeOnly: true);
        return await PageAsync(products, query, cancellationToken);
    }

    public async Task<ProductDetailResponseDto> GetByIdAsync(Guid userId, Guid productId, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .AsNoTracking()
            .Include(x => x.Images)
            .Include(x => x.Category)
            .Include(x => x.Seller)
            .Where(x => x.Id == productId && x.Status == ProductStatus.Active && x.Category.IsActive)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");

        var isFavorite = await dbContext.ProductFavorites.AnyAsync(
            x => x.UserId == userId && x.ProductId == productId,
            cancellationToken);
        return ToDetailDto(product, userId, isFavorite);
    }

    public async Task<PagedResponse<ProductResponseDto>> GetMineAsync(Guid userId, ProductListQueryDto query, CancellationToken cancellationToken)
    {
        ValidateQuery(query);
        var products = ApplyFilters(
            dbContext.Products.AsNoTracking().Include(x => x.Images),
            query,
            activeOnly: false).Where(x => x.SellerUserId == userId);
        return await PageAsync(products, query, cancellationToken);
    }

    public async Task<ProductResponseDto> CreateAsync(Guid userId, CreateProductRequestDto request, CancellationToken cancellationToken)
    {
        var normalized = await ValidateAndNormalizeAsync(request.CategoryId, request.Name, request.Description, request.Price, request.Currency, request.StockQuantity, request.Condition, request.Location, cancellationToken);
        var product = new Product
        {
            SellerUserId = userId,
            CategoryId = request.CategoryId,
            Name = normalized.Name,
            Description = normalized.Description,
            Price = normalized.Price,
            Currency = normalized.Currency,
            StockQuantity = normalized.StockQuantity,
            Condition = request.Condition,
            Status = ProductStatus.Active,
            Location = normalized.Location,
            PublishedAt = DateTimeOffset.UtcNow
        };
        dbContext.Products.Add(product);
        await SaveAsync(cancellationToken);
        return ToDto(product);
    }

    public async Task<ProductResponseDto> UpdateAsync(Guid userId, Guid productId, UpdateProductRequestDto request, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .Where(x => x.Id == productId && x.SellerUserId == userId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");
        var expectedRowVersion = DecodeRowVersion(request.ExpectedRowVersion);
        if (!product.RowVersion.SequenceEqual(expectedRowVersion))
        {
            throw new ConflictException("El producto fue modificado por otro usuario.");
        }
        var normalized = await ValidateAndNormalizeAsync(request.CategoryId, request.Name, request.Description, request.Price, request.Currency, request.StockQuantity, request.Condition, request.Location, cancellationToken);

        product.CategoryId = request.CategoryId;
        product.Name = normalized.Name;
        product.Description = normalized.Description;
        product.Price = normalized.Price;
        product.Currency = normalized.Currency;
        product.StockQuantity = normalized.StockQuantity;
        product.Condition = request.Condition;
        product.Location = normalized.Location;
        await SaveAsync(cancellationToken);
        return ToDto(product);
    }

    public async Task DeleteAsync(Guid userId, Guid productId, CancellationToken cancellationToken)
    {
        var product = await dbContext.Products
            .Where(x => x.Id == productId && x.SellerUserId == userId)
            .SingleOrDefaultAsync(cancellationToken)
            ?? throw new ResourceNotFoundException("El producto no existe.");
        product.IsDeleted = true;
        product.DeletedAt = DateTimeOffset.UtcNow;
        await SaveAsync(cancellationToken);
    }

    private async Task<PagedResponse<ProductResponseDto>> PageAsync(IQueryable<Product> query, ProductListQueryDto options, CancellationToken cancellationToken)
    {
        var totalCount = await query.CountAsync(cancellationToken);
        var pageSize = NormalizePageSize(options.PageSize);
        var page = options.Page;
        var items = await ApplySort(query, options.Sort)
            .ThenByDescending(x => x.CreatedAt)
            .ThenByDescending(x => x.Id)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync(cancellationToken);
        var totalPages = totalCount == 0 ? 0 : (int)Math.Ceiling(totalCount / (double)pageSize);
        return new PagedResponse<ProductResponseDto>(items.Select(ToDto).ToArray(), page, pageSize, totalCount, totalPages);
    }

    private static IQueryable<Product> ApplyFilters(IQueryable<Product> query, ProductListQueryDto options, bool activeOnly)
    {
        if (activeOnly)
        {
            query = query.Where(x => x.Status == ProductStatus.Active && x.Category.IsActive);
        }
        if (options.CategoryId.HasValue) query = query.Where(x => x.CategoryId == options.CategoryId.Value);
        if (options.MinPrice.HasValue) query = query.Where(x => x.Price >= options.MinPrice.Value);
        if (options.MaxPrice.HasValue) query = query.Where(x => x.Price <= options.MaxPrice.Value);
        if (options.Condition.HasValue) query = query.Where(x => x.Condition == options.Condition.Value);
        if (!string.IsNullOrWhiteSpace(options.Search))
        {
            var search = options.Search.Trim();
            query = query.Where(x => x.Name.Contains(search) || x.Description.Contains(search));
        }
        return query;
    }

    private static IOrderedQueryable<Product> ApplySort(IQueryable<Product> query, string? sort)
        => sort?.Trim().ToLowerInvariant() switch
        {
            null or "" or "newest" => query.OrderByDescending(x => x.CreatedAt),
            "oldest" => query.OrderBy(x => x.CreatedAt),
            "priceasc" => query.OrderBy(x => x.Price == null).ThenBy(x => x.Price),
            "pricedesc" => query.OrderBy(x => x.Price == null).ThenByDescending(x => x.Price),
            "name" => query.OrderBy(x => x.Name),
            _ => throw new ValidationException("Sort no es válido.")
        };

    private async Task<(string Name, string Description, decimal? Price, string? Currency, int? StockQuantity, string? Location)> ValidateAndNormalizeAsync(
        Guid categoryId, string name, string description, decimal? price, string? currency, int? stockQuantity, ProductCondition condition, string? location, CancellationToken cancellationToken)
    {
        var normalizedName = name?.Trim() ?? string.Empty;
        var normalizedDescription = description?.Trim() ?? string.Empty;
        var normalizedLocation = string.IsNullOrWhiteSpace(location) ? null : location.Trim();
        if (string.IsNullOrWhiteSpace(normalizedName) || normalizedName.Length > 200) throw new ValidationException("Name es obligatorio y debe tener como máximo 200 caracteres.");
        if (string.IsNullOrWhiteSpace(normalizedDescription) || normalizedDescription.Length > 10000) throw new ValidationException("Description es obligatoria y debe tener como máximo 10000 caracteres.");
        if (price is < 0 || (price.HasValue && decimal.Round(price.Value, 2) != price.Value)) throw new ValidationException("Price debe ser mayor o igual que cero y tener como máximo dos decimales.");
        if (stockQuantity is < 0) throw new ValidationException("StockQuantity debe ser mayor o igual que cero.");
        if (normalizedLocation?.Length > 500) throw new ValidationException("Location no puede superar 500 caracteres.");
        if (!Enum.IsDefined(typeof(ProductCondition), condition)) throw new ValidationException("Condition no es válido.");
        var normalizedCurrency = price.HasValue ? currency?.Trim().ToUpperInvariant() : null;
        if (price.HasValue && (string.IsNullOrWhiteSpace(normalizedCurrency) || normalizedCurrency.Length != 3 || normalizedCurrency.Any(character => !char.IsLetter(character)))) throw new ValidationException("Currency es obligatorio y debe tener tres letras cuando Price tiene valor.");
        var categoryExists = await dbContext.ProductCategories.AnyAsync(x => x.Id == categoryId && x.IsActive, cancellationToken);
        if (!categoryExists) throw new ValidationException("CategoryId debe corresponder a una categoría activa.");
        return (normalizedName, normalizedDescription, price, normalizedCurrency, stockQuantity, normalizedLocation);
    }

    private static void ValidateQuery(ProductListQueryDto query)
    {
        if (query.Page < 1) throw new ValidationException("Page debe ser mayor o igual que uno.");
        if (query.PageSize < 0 || query.PageSize > MaxPageSize) throw new ValidationException($"PageSize debe estar entre uno y {MaxPageSize}.");
        if (query.MinPrice is < 0 || query.MaxPrice is < 0 || (query.MinPrice.HasValue && query.MaxPrice.HasValue && query.MinPrice > query.MaxPrice)) throw new ValidationException("El rango de precios no es válido.");
    }

    private static int NormalizePageSize(int pageSize) => pageSize == 0 ? DefaultPageSize : pageSize;

    private async Task SaveAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            throw new ConflictException("La operación entra en conflicto con otro registro.");
        }
    }

    private static ProductResponseDto ToDto(Product product) => new(
        product.Id, product.CategoryId, product.Name, product.Description, product.Price, product.Currency, product.StockQuantity,
        product.Condition, product.Status, product.Location, product.PublishedAt, product.CreatedAt, EncodeRowVersion(product.RowVersion), ToImages(product));

    private static ProductDetailResponseDto ToDetailDto(Product product, Guid userId, bool isFavorite) => new(
        product.Id, product.CategoryId, product.Name, product.Description, product.Price, product.Currency, product.StockQuantity,
        product.Condition, product.Status, product.Location, product.PublishedAt, product.CreatedAt, EncodeRowVersion(product.RowVersion),
        new ProductCategoryResponseDto(product.Category.Id, product.Category.ParentCategoryId, product.Category.Name, product.Category.Slug, product.Category.Description, product.Category.DisplayOrder, product.Category.IsActive),
        new SellerSummaryDto(product.Seller.Id, product.Seller.UserName, DisplayName(product.Seller), product.Seller.ProfileImageUrl),
        ToImages(product), isFavorite, product.SellerUserId == userId);

    private static string EncodeRowVersion(byte[] rowVersion) => Convert.ToBase64String(rowVersion);

    private static byte[] DecodeRowVersion(string value)
    {
        if (value is null) throw new ValidationException("ExpectedRowVersion es obligatorio.");
        try
        {
            return Convert.FromBase64String(value);
        }
        catch (FormatException)
        {
            throw new ValidationException("ExpectedRowVersion debe ser Base64 válido.");
        }
    }

    private static IReadOnlyCollection<ProductImageResponseDto> ToImages(Product product)
        => product.Images.OrderBy(x => x.DisplayOrder).ThenBy(x => x.Id).Select(x => new ProductImageResponseDto(x.Id, x.Url, x.ThumbnailUrl, x.DisplayOrder, x.IsPrimary)).ToArray();

    private static string? DisplayName(User seller)
    {
        var name = string.Join(" ", new[] { seller.FirstName, seller.LastName }.Where(x => !string.IsNullOrWhiteSpace(x)));
        return string.IsNullOrWhiteSpace(name) ? null : name;
    }
}
