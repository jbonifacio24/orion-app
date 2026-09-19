import '../entities/product.dart';
import '../repositories/marketplace_repository.dart';

class GetFavorites { const GetFavorites(this._repository); final MarketplaceRepository _repository; Future<List<Product>> call() => _repository.getFavorites(); }
