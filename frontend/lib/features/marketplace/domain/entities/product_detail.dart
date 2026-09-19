import 'product.dart';
import 'product_category.dart';
import 'seller_summary.dart';

class ProductDetail extends Product {
  const ProductDetail({required super.id, required super.categoryId, required super.name, required super.description, required super.price, required super.currency, required super.stockQuantity, required super.condition, required super.status, required super.location, required super.publishedAt, required super.createdAt, required super.rowVersion, required super.images, required this.category, required this.seller, required this.isFavorite, required this.isOwner});

  final ProductCategory category;
  final SellerSummary seller;
  final bool isFavorite;
  final bool isOwner;

  ProductDetail copyWith({bool? isFavorite}) => ProductDetail(
        id: id,
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        currency: currency,
        stockQuantity: stockQuantity,
        condition: condition,
        status: status,
        location: location,
        publishedAt: publishedAt,
        createdAt: createdAt,
        rowVersion: rowVersion,
        images: images,
        category: category,
        seller: seller,
        isFavorite: isFavorite ?? this.isFavorite,
        isOwner: isOwner,
      );
}