import 'product_image.dart';

enum ProductCondition { newProduct, used }

enum ProductStatus { draft, active, sold, archived }

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.stockQuantity,
    required this.condition,
    required this.status,
    required this.location,
    required this.publishedAt,
    required this.createdAt,
    required this.rowVersion,
    required this.images,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final double? price;
  final String? currency;
  final int? stockQuantity;
  final ProductCondition condition;
  final ProductStatus status;
  final String? location;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final String rowVersion;
  final List<ProductImage> images;

  bool get isNegotiable => price == null;
}
