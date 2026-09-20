import 'package:dio/dio.dart';

import '../../domain/entities/product_filters.dart';
import '../../domain/entities/product_image_upload.dart';
import '../models/marketplace_models.dart';

class MarketplaceDataSource {
  const MarketplaceDataSource(this._dio);
  final Dio _dio;

  Future<PagedProductsModel> getProducts(ProductFilters filters, {bool mine = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(mine ? '/api/products/mine' : '/api/products', queryParameters: filters.toQuery(page: 1));
    return PagedProductsModel.fromJson(response.data!);
  }

  Future<PagedProductsModel> getPage(ProductFilters filters, int page, {bool mine = false}) async {
    final response = await _dio.get<Map<String, dynamic>>(mine ? '/api/products/mine' : '/api/products', queryParameters: filters.toQuery(page: page));
    return PagedProductsModel.fromJson(response.data!);
  }

  Future<ProductDetailModel> getProduct(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/products/$id');
    return ProductDetailModel.fromJson(response.data!);
  }

  Future<ProductModel> create(CreateProductRequestModel request) async {
    final response = await _dio.post<Map<String, dynamic>>('/api/products', data: request.toJson());
    return ProductModel.fromJson(response.data!);
  }

  Future<ProductModel> update(String id, UpdateProductRequestModel request) async {
    final response = await _dio.put<Map<String, dynamic>>('/api/products/$id', data: request.toJson());
    return ProductModel.fromJson(response.data!);
  }

  Future<void> delete(String id) => _dio.delete<void>('/api/products/$id');

  Future<ProductImageModel> uploadProductImage(String productId, ProductImageUpload upload) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/products/$productId/images',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(upload.bytes, filename: upload.fileName),
      }),
      options: Options(extra: {
        'rebuildMultipartData': () => FormData.fromMap({
              'file': MultipartFile.fromBytes(upload.bytes, filename: upload.fileName),
            }),
      }),
    );
    return ProductImageModel.fromJson(response.data!);
  }

  Future<void> deleteProductImage(String productId, String imageId) => _dio.delete<void>('/api/products/$productId/images/$imageId');

  Future<ProductImageModel> setPrimaryProductImage(String productId, String imageId) async {
    final response = await _dio.put<Map<String, dynamic>>('/api/products/$productId/images/$imageId/primary');
    return ProductImageModel.fromJson(response.data!);
  }

  Future<List<ProductCategoryModel>> getCategories() async {
    final response = await _dio.get<List<dynamic>>('/api/categories');
    return (response.data ?? const []).map((item) => ProductCategoryModel.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<ProductModel>> getFavorites() async {
    final response = await _dio.get<List<dynamic>>('/api/favorites');
    return (response.data ?? const []).map((item) => ProductModel.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<void> addFavorite(String id) => _dio.post<void>('/api/products/$id/favorite');
  Future<void> removeFavorite(String id) => _dio.delete<void>('/api/products/$id/favorite');
}
