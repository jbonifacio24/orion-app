import '../repositories/marketplace_repository.dart';

class RemoveFavorite { const RemoveFavorite(this._repository); final MarketplaceRepository _repository; Future<void> call(String id) => _repository.removeFavorite(id); }
