import '../../../../core/error/app_failure.dart';
import '../../domain/entities/paged_products.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/seller_summary.dart';
import '../../domain/entities/product_detail.dart';

ProductCondition _condition(Object? value) => switch (value) {
      0 => ProductCondition.newProduct,
      1 => ProductCondition.used,
      _ => throw const SerializationFailure('Condición de producto desconocida.'),
    };

ProductStatus _status(Object? value) => switch (value) {
      0 => ProductStatus.draft,
      1 => ProductStatus.active,
      2 => ProductStatus.sold,
      3 => ProductStatus.archived,
      _ => throw const SerializationFailure('Estado de producto desconocido.'),
    };

class ProductImageModel extends ProductImage {
  const ProductImageModel({required super.id, required super.url, required super.thumbnailUrl, required super.displayOrder, required super.isPrimary});

  factory ProductImageModel.fromJson(Map<String, dynamic> json) => ProductImageModel(
        id: json['id'] as String,
        url: json['url'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String?,
        displayOrder: json['displayOrder'] as int? ?? 0,
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
}

List<ProductImageModel> _images(Object? value) => (value as List<dynamic>? ?? const [])
    .map((item) => ProductImageModel.fromJson(item as Map<String, dynamic>))
    .toList(growable: false);

class ProductModel extends Product {
  const ProductModel({required super.id, required super.categoryId, required super.name, required super.description, required super.price, required super.currency, required super.stockQuantity, required super.condition, required super.status, required super.location, required super.publishedAt, required super.createdAt, required super.rowVersion, required super.images});

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        stockQuantity: json['stockQuantity'] as int?,
        condition: _condition(json['condition']),
        status: _status(json['status']),
        location: json['location'] as String?,
        publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        rowVersion: json['rowVersion'] as String? ?? '',
        images: _images(json['images']),
      );
}

class ProductCategoryModel extends ProductCategory {
  const ProductCategoryModel({required super.id, required super.parentCategoryId, required super.name, required super.slug, required super.description, required super.displayOrder, required super.isActive});

  factory ProductCategoryModel.fromJson(Map<String, dynamic> json) => ProductCategoryModel(
        id: json['id'] as String,
        parentCategoryId: json['parentCategoryId'] as String?,
        name: json['name'] as String? ?? '',
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String?,
        displayOrder: json['displayOrder'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? false,
      );
}

class SellerSummaryModel extends SellerSummary {
  const SellerSummaryModel({required super.id, required super.userName, required super.displayName, required super.profileImageUrl});

  factory SellerSummaryModel.fromJson(Map<String, dynamic> json) => SellerSummaryModel(
        id: json['id'] as String,
        userName: json['userName'] as String? ?? '',
        displayName: json['displayName'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
      );
}

class ProductDetailModel extends ProductDetail {
  const ProductDetailModel({required super.id, required super.categoryId, required super.name, required super.description, required super.price, required super.currency, required super.stockQuantity, required super.condition, required super.status, required super.location, required super.publishedAt, required super.createdAt, required super.rowVersion, required super.images, required super.category, required super.seller, required super.isFavorite, required super.isOwner});

  factory ProductDetailModel.fromJson(Map<String, dynamic> json) {
    final product = ProductModel.fromJson(json);
    return ProductDetailModel(
      id: product.id,
      categoryId: product.categoryId,
      name: product.name,
      description: product.description,
      price: product.price,
      currency: product.currency,
      stockQuantity: product.stockQuantity,
      condition: product.condition,
      status: product.status,
      location: product.location,
      publishedAt: product.publishedAt,
      createdAt: product.createdAt,
      rowVersion: product.rowVersion,
      images: product.images,
      category: ProductCategoryModel.fromJson(json['category'] as Map<String, dynamic>),
      seller: SellerSummaryModel.fromJson(json['seller'] as Map<String, dynamic>),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }
}

class PagedProductsModel extends PagedProducts {
  const PagedProductsModel({required super.items, required super.page, required super.pageSize, required super.totalCount, required super.totalPages});

  factory PagedProductsModel.fromJson(Map<String, dynamic> json) => PagedProductsModel(
        items: (json['items'] as List<dynamic>? ?? const []).map((item) => ProductModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalCount: json['totalCount'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
      );
}

class CreateProductRequestModel {
  const CreateProductRequestModel({required this.categoryId, required this.name, required this.description, required this.price, required this.currency, required this.stockQuantity, required this.condition, required this.location});
  final String categoryId;
  final String name;
  final String description;
  final double? price;
  final String? currency;
  final int? stockQuantity;
  final ProductCondition condition;
  final String? location;

  Map<String, dynamic> toJson() => {'categoryId': categoryId, 'name': name, 'description': description, 'price': price, 'currency': currency, 'stockQuantity': stockQuantity, 'condition': condition.index, 'location': location};
}

class UpdateProductRequestModel extends CreateProductRequestModel {
  const UpdateProductRequestModel({required super.categoryId, required super.name, required super.description, required super.price, required super.currency, required super.stockQuantity, required super.condition, required super.location, required this.expectedRowVersion});
  final String expectedRowVersion;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'expectedRowVersion': expectedRowVersion};
}
