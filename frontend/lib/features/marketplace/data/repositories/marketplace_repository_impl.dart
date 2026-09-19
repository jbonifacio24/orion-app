import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/paged_products.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_detail.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../datasources/marketplace_data_source.dart';
import '../models/marketplace_models.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  const MarketplaceRepositoryImpl(this._dataSource);
  final MarketplaceDataSource _dataSource;

  @override
  Future<PagedProducts> getProducts(ProductFilters filters, {int page = 1}) => _map(() => _dataSource.getPage(filters, page));

  @override
  Future<ProductDetail> getProduct(String id) => _map(() => _dataSource.getProduct(id));

  @override
  Future<PagedProducts> getMyProducts(ProductFilters filters, {int page = 1}) => _map(() => _dataSource.getPage(filters, page, mine: true));

  @override
  Future<Product> createProduct({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) => _map(() => _dataSource.create(CreateProductRequestModel(categoryId: categoryId, name: name, description: description, price: price, currency: currency, stockQuantity: stockQuantity, condition: condition, location: location)));

  @override
  Future<Product> updateProduct({required String id, required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location, required String expectedRowVersion}) => _map(() => _dataSource.update(id, UpdateProductRequestModel(categoryId: categoryId, name: name, description: description, price: price, currency: currency, stockQuantity: stockQuantity, condition: condition, location: location, expectedRowVersion: expectedRowVersion)));

  @override
  Future<void> deleteProduct(String id) => _map(() => _dataSource.delete(id));

  @override
  Future<List<ProductCategory>> getCategories() => _map(() => _dataSource.getCategories());

  @override
  Future<List<Product>> getFavorites() => _map(() => _dataSource.getFavorites());

  @override
  Future<void> addFavorite(String id) => _map(() => _dataSource.addFavorite(id));

  @override
  Future<void> removeFavorite(String id) => _map(() => _dataSource.removeFavorite(id));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
