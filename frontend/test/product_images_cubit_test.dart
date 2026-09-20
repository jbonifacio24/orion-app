import 'dart:async';
import 'dart:typed_data';

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
import 'package:motohub/features/marketplace/domain/services/product_image_picker.dart';
import 'package:motohub/features/marketplace/domain/usecases/delete_product_image.dart';
import 'package:motohub/features/marketplace/domain/usecases/get_product_detail.dart';
import 'package:motohub/features/marketplace/domain/usecases/set_primary_product_image.dart';
import 'package:motohub/features/marketplace/domain/usecases/upload_product_image.dart';
import 'package:motohub/features/marketplace/presentation/cubit/product_images_cubit.dart';

void main() {
  test('accepts only remaining capacity and reports omitted selections', () async {
    final repository = _ImageRepository(images: List.generate(9, (index) => _image('remote-$index', index, index == 0)));
    final picker = _FakePicker(List.generate(3, (index) => _upload('local-$index.jpg')));
    final cubit = _createCubit(repository, picker);
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.selectImages();

    expect(cubit.state.localSelections, hasLength(1));
    expect(cubit.state.operationError, contains('Se omitieron 2'));
  });

  test('stops on failure and retry sends only failed and pending selections', () async {
    final repository = _ImageRepository(failFileName: 'b.jpg');
    final picker = _FakePicker([_upload('a.jpg'), _upload('b.jpg'), _upload('c.jpg')]);
    final cubit = _createCubit(repository, picker);
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.selectImages();
    await cubit.uploadPending();

    expect(repository.uploadedNames, ['a.jpg']);
    expect(cubit.state.uploadedImages, hasLength(1));
    expect(cubit.state.localSelections.map((item) => item.upload.fileName), ['b.jpg', 'c.jpg']);

    repository.failFileName = null;
    await cubit.uploadPending();

    expect(repository.uploadedNames, ['a.jpg', 'b.jpg', 'c.jpg']);
    expect(cubit.state.localSelections, isEmpty);
  });

  test('ignores detail refresh while upload is active and preserves completed uploads', () async {
    final started = Completer<void>();
    final gate = Completer<void>();
    final repository = _ImageRepository(uploadStarted: started, uploadGate: gate);
    final cubit = _createCubit(repository, _FakePicker([_upload('a.jpg'), _upload('b.jpg')]));
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.selectImages();
    final upload = cubit.uploadPending();
    await started.future;

    await cubit.load('product-1');
    expect(repository.detailCalls, 1);
    expect(cubit.state.uploadedImages.map((image) => image.id), ['a.jpg']);

    gate.complete();
    await upload;
    expect(cubit.state.uploadedImages.map((image) => image.id), ['a.jpg', 'b.jpg']);
  });

  test('delete primary remains successful when detail refresh fails', () async {
    final repository = _ImageRepository(images: [_image('a', 0, true), _image('b', 1, false)], failDetailAfterFirstLoad: true);
    final cubit = _createCubit(repository, _FakePicker(const []));
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.deleteImage(repository.images.first);

    expect(cubit.state.uploadedImages.map((image) => image.id), ['b']);
    expect(cubit.state.syncWarning, isNotNull);
    expect(cubit.state.error, isNull);
  });

  test('delete primary uses the refreshed backend primary', () async {
    final repository = _ImageRepository(images: [_image('a', 0, true), _image('b', 1, false)], refreshedImages: [_image('b', 0, true)]);
    final cubit = _createCubit(repository, _FakePicker(const []));
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.deleteImage(repository.images.first);

    expect(cubit.state.uploadedImages, hasLength(1));
    expect(cubit.state.uploadedImages.single.id, 'b');
    expect(cubit.state.uploadedImages.single.isPrimary, isTrue);
  });

  test('delete non-primary removes only the target image', () async {
    final repository = _ImageRepository(images: [_image('a', 0, true), _image('b', 1, false)]);
    final cubit = _createCubit(repository, _FakePicker(const []));
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.deleteImage(repository.images[1]);

    expect(cubit.state.uploadedImages.map((image) => image.id), ['a']);
    expect(cubit.state.uploadedImages.single.isPrimary, isTrue);
    expect(repository.detailCalls, 1);
  });

  test('set primary marks the target and clears the previous primary', () async {
    final repository = _ImageRepository(images: [_image('a', 0, true), _image('b', 1, false)]);
    final cubit = _createCubit(repository, _FakePicker(const []));
    addTearDown(cubit.close);

    await cubit.load('product-1');
    await cubit.setPrimary(repository.images[1]);

    expect(cubit.state.uploadedImages.firstWhere((image) => image.id == 'a').isPrimary, isFalse);
    expect(cubit.state.uploadedImages.firstWhere((image) => image.id == 'b').isPrimary, isTrue);
  });

  test('rejects an empty local file', () async {
    final cubit = _createCubit(_ImageRepository(), _FakePicker([_upload('empty.jpg', sizeBytes: 0)]));
    addTearDown(cubit.close);
    await cubit.load('product-1');
    await cubit.selectImages();
    expect(cubit.state.localSelections, isEmpty);
    expect(cubit.state.operationError, contains('no válido'));
  });

  test('rejects a file larger than 5 MB', () async {
    final cubit = _createCubit(_ImageRepository(), _FakePicker([_upload('large.jpg', sizeBytes: ProductImagesCubit.maxFileSize + 1)]));
    addTearDown(cubit.close);
    await cubit.load('product-1');
    await cubit.selectImages();
    expect(cubit.state.localSelections, isEmpty);
    expect(cubit.state.operationError, contains('no válido'));
  });

  test('rejects SVG and other unsupported extensions', () async {
    final cubit = _createCubit(_ImageRepository(), _FakePicker([_upload('vector.svg'), _upload('photo.gif')]));
    addTearDown(cubit.close);
    await cubit.load('product-1');
    await cubit.selectImages();
    expect(cubit.state.localSelections, isEmpty);
    expect(cubit.state.operationError, contains('2 archivo(s)'));
  });

  test('recognizes non-owner and does not invoke the picker', () async {
    final picker = _FakePicker([_upload('blocked.jpg')]);
    final cubit = _createCubit(_ImageRepository(owner: false), picker);
    addTearDown(cubit.close);
    await cubit.load('product-1');
    await cubit.selectImages();
    expect(cubit.state.isOwner, isFalse);
    expect(picker.calls, 0);
    expect(cubit.state.localSelections, isEmpty);
  });
}

ProductImagesCubit _createCubit(_ImageRepository repository, IProductImagePicker picker) => ProductImagesCubit(GetProductDetail(repository), picker, UploadProductImage(repository), DeleteProductImage(repository), SetPrimaryProductImage(repository));

ProductImageUpload _upload(String fileName, {int? sizeBytes}) => ProductImageUpload(bytes: Uint8List.fromList([1, 2, 3]), fileName: fileName, sizeBytes: sizeBytes ?? 3);
ProductImage _image(String id, int order, bool primary) => ProductImage(id: id, url: '/media/$id.jpg', thumbnailUrl: null, displayOrder: order, isPrimary: primary);

class _FakePicker implements IProductImagePicker {
  _FakePicker(this.selections);
  final List<ProductImageUpload> selections;
  int calls = 0;
  @override
  Future<List<ProductImageUpload>> pickImages() async {
    calls++;
    return selections;
  }
}

class _ImageRepository implements MarketplaceRepository {
  _ImageRepository({this.images = const [], this.failFileName, this.uploadStarted, this.uploadGate, this.refreshedImages, this.failDetailAfterFirstLoad = false, this.owner = true});
  final List<ProductImage> images;
  String? failFileName;
  final Completer<void>? uploadStarted;
  final Completer<void>? uploadGate;
  final List<ProductImage>? refreshedImages;
  final bool failDetailAfterFirstLoad;
  final bool owner;
  int detailCalls = 0;
  final List<String> uploadedNames = [];

  @override
  Future<ProductDetail> getProduct(String id) async {
    detailCalls++;
    if (failDetailAfterFirstLoad && detailCalls > 1) throw const NetworkFailure('sync failed');
    return _detail(detailCalls > 1 && refreshedImages != null ? refreshedImages! : images, owner: owner);
  }

  @override
  Future<ProductImage> uploadProductImage(String productId, ProductImageUpload upload) async {
    if (failFileName == upload.fileName) {
      throw const NetworkFailure('upload failed');
    }
    if (upload.fileName == 'b.jpg' && uploadStarted != null) {
      if (!uploadStarted!.isCompleted) uploadStarted!.complete();
      await uploadGate!.future;
    }
    uploadedNames.add(upload.fileName);
    return _image(upload.fileName, uploadedNames.length - 1, uploadedNames.length == 1 && images.isEmpty);
  }

  @override
  Future<void> deleteProductImage(String productId, String imageId) async {}

  @override
  Future<ProductImage> setPrimaryProductImage(String productId, String imageId) async => _image(imageId, 0, true);

  @override
  Future<PagedProducts> getProducts(ProductFilters filters, {int page = 1}) => throw UnimplementedError();
  @override
  Future<PagedProducts> getMyProducts(ProductFilters filters, {int page = 1}) => throw UnimplementedError();
  @override
  Future<Product> createProduct({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) => throw UnimplementedError();
  @override
  Future<Product> updateProduct({required String id, required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location, required String expectedRowVersion}) => throw UnimplementedError();
  @override
  Future<void> deleteProduct(String id) => throw UnimplementedError();
  @override
  Future<List<ProductCategory>> getCategories() => throw UnimplementedError();
  @override
  Future<List<Product>> getFavorites() => throw UnimplementedError();
  @override
  Future<void> addFavorite(String id) => throw UnimplementedError();
  @override
  Future<void> removeFavorite(String id) => throw UnimplementedError();
}

ProductDetail _detail(List<ProductImage> images, {bool owner = true}) => ProductDetail(id: 'product-1', categoryId: 'category-1', name: 'Part', description: 'Description', price: null, currency: null, stockQuantity: null, condition: ProductCondition.used, status: ProductStatus.active, location: null, publishedAt: null, createdAt: DateTime.utc(2026), rowVersion: 'AQID', images: images, category: const ProductCategory(id: 'category-1', parentCategoryId: null, name: 'Parts', slug: 'parts', description: null, displayOrder: 0, isActive: true), seller: const SellerSummary(id: 'seller-1', userName: 'owner', displayName: 'Owner', profileImageUrl: null), isFavorite: false, isOwner: owner);