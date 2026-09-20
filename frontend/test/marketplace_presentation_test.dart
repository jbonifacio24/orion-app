import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/marketplace/domain/entities/paged_products.dart';
import 'package:motohub/features/marketplace/domain/entities/product.dart';
import 'package:motohub/features/marketplace/domain/entities/product_category.dart';
import 'package:motohub/features/marketplace/domain/entities/product_detail.dart';
import 'package:motohub/features/marketplace/domain/entities/product_filters.dart';
import 'package:motohub/features/marketplace/domain/entities/product_image.dart';
import 'package:motohub/features/marketplace/domain/entities/product_image_upload.dart';
import 'package:motohub/features/marketplace/domain/entities/seller_summary.dart';
import 'package:motohub/features/marketplace/domain/repositories/marketplace_repository.dart';
import 'package:motohub/features/marketplace/domain/usecases/add_favorite.dart';
import 'package:motohub/features/marketplace/domain/usecases/delete_product.dart';
import 'package:motohub/features/marketplace/domain/usecases/get_product_detail.dart';
import 'package:motohub/features/marketplace/domain/usecases/remove_favorite.dart';
import 'package:motohub/features/marketplace/domain/usecases/create_product.dart';
import 'package:motohub/features/marketplace/domain/usecases/update_product.dart';
import 'package:motohub/features/marketplace/presentation/cubit/product_detail_cubit.dart';
import 'package:motohub/features/marketplace/presentation/cubit/product_form_cubit.dart';
import 'package:motohub/features/marketplace/presentation/widgets/product_image.dart' show selectProductImageUrl;
import 'package:motohub/features/marketplace/presentation/widgets/product_form.dart';

void main() {
  test('favorite success remains loaded when synchronization fails', () async {
    final repository = _FakeMarketplaceRepository(failDetailAfterFirstLoad: true);
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.toggleFavorite();

    final state = cubit.state as ProductDetailLoaded;
    expect(state.product.isFavorite, isTrue);
    expect(state.syncWarning, isNotNull);
  });

  test('favorite mutation failure preserves the previous state as data', () async {
    final repository = _FakeMarketplaceRepository(failAddFavorite: true);
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.toggleFavorite();

    final state = cubit.state as ProductDetailFailure;
    expect(state.product?.isFavorite, isFalse);
    expect(state.message, isNotEmpty);
  });

  test('double toggle does not send concurrent mutations', () async {
    final mutation = Completer<void>();
    final repository = _FakeMarketplaceRepository(addFavoriteCompleter: mutation);
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load('product-1');
    final firstToggle = cubit.toggleFavorite();
    await Future<void>.delayed(Duration.zero);
    await cubit.toggleFavorite();

    expect(repository.addFavoriteCalls, 1);
    mutation.complete();
    await firstToggle;
  });

  test('selects primary image before display-order fallback', () {
    final images = [
      const ProductImage(id: 'second', url: 'second', thumbnailUrl: null, displayOrder: 2, isPrimary: false),
      const ProductImage(id: 'primary', url: 'primary', thumbnailUrl: null, displayOrder: 3, isPrimary: true),
      const ProductImage(id: 'first', url: 'first', thumbnailUrl: null, displayOrder: 1, isPrimary: false),
    ];

    expect(selectProductImageUrl(images), 'primary');
    expect(selectProductImageUrl(images.sublist(0, 1)), 'second');
    expect(selectProductImageUrl(const []), isNull);
  });

  test('edit submission forwards the detail rowVersion unchanged', () async {
    final repository = _FakeMarketplaceRepository();
    final cubit = ProductFormCubit(
      CreateProduct(repository),
      UpdateProduct(repository),
      mode: ProductFormMode.edit,
      initial: _detail,
    );
    addTearDown(cubit.close);

    final submitted = await cubit.submit(
      categoryId: 'category-1',
      name: 'Casco actualizado',
      description: 'Integral',
      condition: ProductCondition.used,
    );

    expect(submitted, isTrue);
    expect(repository.expectedRowVersion, 'AQID');
  });

  testWidgets('rejects negative price and stock and reacts to price changes', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProductForm(
            categories: const [ProductCategory(id: 'category-1', parentCategoryId: null, name: 'Accesorios', slug: 'accesorios', description: null, displayOrder: 1, isActive: true)],
            initial: null,
            loading: false,
            onSubmit: ({required categoryId, required name, required description, price, currency, stockQuantity, required condition, location}) async {
              submissions++;
              return true;
            },
          ),
        ),
      ),
    ));

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(3)).enabled, isFalse);
    await tester.enterText(fields.at(2), '10');
    await tester.pump();
    expect(tester.widget<TextFormField>(fields.at(3)).enabled, isTrue);
    await tester.enterText(fields.at(2), '-1');
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(submissions, 0);
    await tester.enterText(fields.at(2), '');
    await tester.enterText(fields.at(4), '-1');
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(submissions, 0);
  });
}

ProductDetailCubit _createCubit(_FakeMarketplaceRepository repository) => ProductDetailCubit(
      GetProductDetail(repository),
      AddFavorite(repository),
      RemoveFavorite(repository),
      DeleteProduct(repository),
    );

class _FakeMarketplaceRepository implements MarketplaceRepository {
  _FakeMarketplaceRepository({this.failDetailAfterFirstLoad = false, this.failAddFavorite = false, this.addFavoriteCompleter});

  final bool failDetailAfterFirstLoad;
  final bool failAddFavorite;
  final Completer<void>? addFavoriteCompleter;
  int detailCalls = 0;
  int addFavoriteCalls = 0;
  String? expectedRowVersion;

  @override
  Future<ProductDetail> getProduct(String id) async {
    detailCalls++;
    if (failDetailAfterFirstLoad && detailCalls > 1) {
      throw const NetworkFailure('sync failed');
    }
    return _detail;
  }

  @override
  Future<void> addFavorite(String id) async {
    addFavoriteCalls++;
    if (failAddFavorite) throw const NetworkFailure('favorite failed');
    if (addFavoriteCompleter != null) await addFavoriteCompleter!.future;
  }

  @override
  Future<void> removeFavorite(String id) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<PagedProducts> getProducts(ProductFilters filters, {int page = 1}) => throw UnimplementedError();

  @override
  Future<PagedProducts> getMyProducts(ProductFilters filters, {int page = 1}) => throw UnimplementedError();

  @override
  Future<Product> createProduct({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) => throw UnimplementedError();

  @override
  Future<Product> updateProduct({required String id, required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location, required String expectedRowVersion}) async { this.expectedRowVersion = expectedRowVersion; return _detail; }

  @override
  Future<List<ProductCategory>> getCategories() => throw UnimplementedError();

  @override
  Future<List<Product>> getFavorites() => throw UnimplementedError();

  @override
  Future<ProductImage> uploadProductImage(String productId, ProductImageUpload upload) => throw UnimplementedError();

  @override
  Future<void> deleteProductImage(String productId, String imageId) => throw UnimplementedError();

  @override
  Future<ProductImage> setPrimaryProductImage(String productId, String imageId) => throw UnimplementedError();
}

final _detail = ProductDetail(
  id: 'product-1',
  categoryId: 'category-1',
  name: 'Casco',
  description: 'Integral',
  price: null,
  currency: null,
  stockQuantity: null,
  condition: ProductCondition.used,
  status: ProductStatus.active,
  location: 'Lima',
  publishedAt: null,
  createdAt: DateTime.utc(2026, 9, 19),
  rowVersion: 'AQID',
  images: const [],
  category: const ProductCategory(id: 'category-1', parentCategoryId: null, name: 'Accesorios', slug: 'accesorios', description: null, displayOrder: 1, isActive: true),
  seller: const SellerSummary(id: 'seller-1', userName: 'rider', displayName: 'Rider', profileImageUrl: null),
  isFavorite: false,
  isOwner: true,
);
