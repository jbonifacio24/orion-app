import '../entities/product_image.dart';
import '../entities/product_image_upload.dart';
import '../repositories/marketplace_repository.dart';

class UploadProductImage {
  const UploadProductImage(this._repository);
  final MarketplaceRepository _repository;

  Future<ProductImage> call(String productId, ProductImageUpload upload) => _repository.uploadProductImage(productId, upload);
}