import '../entities/product_image.dart';
import '../repositories/marketplace_repository.dart';

class SetPrimaryProductImage {
  const SetPrimaryProductImage(this._repository);
  final MarketplaceRepository _repository;

  Future<ProductImage> call(String productId, String imageId) => _repository.setPrimaryProductImage(productId, imageId);
}