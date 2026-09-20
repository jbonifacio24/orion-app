import '../entities/paged_products.dart';
import '../entities/product.dart';
import '../entities/product_category.dart';
import '../entities/product_filters.dart';
import '../entities/product_detail.dart';
import '../entities/product_image.dart';
import '../entities/product_image_upload.dart';

abstract interface class MarketplaceRepository {
  Future<PagedProducts> getProducts(ProductFilters filters, {int page = 1});
  Future<ProductDetail> getProduct(String id);
  Future<PagedProducts> getMyProducts(ProductFilters filters, {int page = 1});
  Future<Product> createProduct({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location});
  Future<Product> updateProduct({required String id, required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location, required String expectedRowVersion});
  Future<void> deleteProduct(String id);
  Future<List<ProductCategory>> getCategories();
  Future<List<Product>> getFavorites();
  Future<void> addFavorite(String id);
  Future<void> removeFavorite(String id);
  Future<ProductImage> uploadProductImage(String productId, ProductImageUpload upload);
  Future<void> deleteProductImage(String productId, String imageId);
  Future<ProductImage> setPrimaryProductImage(String productId, String imageId);
}
