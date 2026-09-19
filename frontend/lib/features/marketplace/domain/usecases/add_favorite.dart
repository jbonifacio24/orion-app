import '../repositories/marketplace_repository.dart';

class AddFavorite { const AddFavorite(this._repository); final MarketplaceRepository _repository; Future<void> call(String id) => _repository.addFavorite(id); }
