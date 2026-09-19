import '../repositories/marketplace_repository.dart';

class DeleteProduct { const DeleteProduct(this._repository); final MarketplaceRepository _repository; Future<void> call(String id) => _repository.deleteProduct(id); }
