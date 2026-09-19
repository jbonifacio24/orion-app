import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/marketplace/data/models/marketplace_models.dart';
import 'package:motohub/features/marketplace/domain/entities/product.dart';

void main() {
  test('maps product JSON including nullable price and opaque rowVersion', () {
    final product = ProductModel.fromJson({
      'id': 'product-1',
      'categoryId': 'category-1',
      'name': 'Casco',
      'description': 'Integral',
      'price': null,
      'currency': null,
      'stockQuantity': null,
      'condition': 1,
      'status': 1,
      'location': 'Lima',
      'publishedAt': '2026-09-19T12:00:00Z',
      'createdAt': '2026-09-19T12:00:00Z',
      'rowVersion': 'AQID',
      'images': [
        {'id': 'image-1', 'url': 'https://image', 'thumbnailUrl': null, 'displayOrder': 0, 'isPrimary': true},
      ],
    });

    expect(product.price, isNull);
    expect(product.isNegotiable, isTrue);
    expect(product.condition, ProductCondition.used);
    expect(product.status, ProductStatus.active);
    expect(product.rowVersion, 'AQID');
    expect(product.images.single.isPrimary, isTrue);
  });

  test('maps product detail seller, category and favorite state', () {
    final detail = ProductDetailModel.fromJson({
      'id': 'product-1',
      'categoryId': 'category-1',
      'name': 'Casco',
      'description': 'Integral',
      'price': 120.5,
      'currency': 'PEN',
      'stockQuantity': 2,
      'condition': 0,
      'status': 1,
      'location': null,
      'publishedAt': null,
      'createdAt': '2026-09-19T12:00:00Z',
      'rowVersion': 'token',
      'images': [],
      'category': {'id': 'category-1', 'parentCategoryId': null, 'name': 'Accesorios', 'slug': 'accesorios', 'description': null, 'displayOrder': 1, 'isActive': true},
      'seller': {'id': 'seller-1', 'userName': 'rider', 'displayName': 'Rider', 'profileImageUrl': null},
      'isFavorite': true,
      'isOwner': true,
    });

    expect(detail.category.slug, 'accesorios');
    expect(detail.seller.userName, 'rider');
    expect(detail.isFavorite, isTrue);
    expect(detail.isOwner, isTrue);
    expect(detail.rowVersion, 'token');
  });

  test('maps every supported condition and status explicitly', () {
    for (final entry in {0: ProductCondition.newProduct, 1: ProductCondition.used}.entries) {
      expect(ProductModel.fromJson(_productJson(condition: entry.key)) .condition, entry.value);
    }
    for (final entry in {0: ProductStatus.draft, 1: ProductStatus.active, 2: ProductStatus.sold, 3: ProductStatus.archived}.entries) {
      expect(ProductModel.fromJson(_productJson(status: entry.key)).status, entry.value);
    }
  });

  test('fails explicitly for unknown condition and status', () {
    expect(() => ProductModel.fromJson(_productJson(condition: 9)), throwsA(isA<SerializationFailure>()));
    expect(() => ProductModel.fromJson(_productJson(status: 9)), throwsA(isA<SerializationFailure>()));
  });
}

Map<String, dynamic> _productJson({int condition = 1, int status = 1}) => {
      'id': 'product-1',
      'categoryId': 'category-1',
      'name': 'Casco',
      'description': 'Integral',
      'price': null,
      'currency': null,
      'stockQuantity': null,
      'condition': condition,
      'status': status,
      'location': null,
      'publishedAt': null,
      'createdAt': '2026-09-19T12:00:00Z',
      'rowVersion': 'AQID',
      'images': <Map<String, dynamic>>[],
    };
