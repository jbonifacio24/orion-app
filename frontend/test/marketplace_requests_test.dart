import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/marketplace/data/models/marketplace_models.dart';
import 'package:motohub/features/marketplace/domain/entities/product.dart';

void main() {
  test('create payload contains only editable product fields', () {
    final payload = const CreateProductRequestModel(
      categoryId: 'category-1',
      name: 'Casco',
      description: 'Integral',
      price: null,
      currency: null,
      stockQuantity: null,
      condition: ProductCondition.used,
      location: 'Lima',
    ).toJson();

    expect(payload['price'], isNull);
    expect(payload['currency'], isNull);
    expect(payload['condition'], 1);
    expect(payload.containsKey('sellerUserId'), isFalse);
    expect(payload.containsKey('status'), isFalse);
    expect(payload.containsKey('rowVersion'), isFalse);
  });

  test('update payload sends opaque expectedRowVersion', () {
    final payload = const UpdateProductRequestModel(
      categoryId: 'category-1',
      name: 'Casco',
      description: 'Integral',
      price: 120,
      currency: 'PEN',
      stockQuantity: 2,
      condition: ProductCondition.newProduct,
      location: 'Lima',
      expectedRowVersion: 'AQID',
    ).toJson();

    expect(payload['expectedRowVersion'], 'AQID');
    expect(payload['condition'], 0);
    expect(payload.containsKey('rowVersion'), isFalse);
    expect(payload.containsKey('sellerUserId'), isFalse);
    expect(payload.containsKey('status'), isFalse);
  });
}
