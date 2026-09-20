import '../repositories/marketplace_repository.dart';

class DeleteProductImage {
  const DeleteProductImage(this._repository);
  final MarketplaceRepository _repository;

  Future<void> call(String productId, String imageId) => _repository.deleteProductImage(productId, imageId);
}