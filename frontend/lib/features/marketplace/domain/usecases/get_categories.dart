import '../entities/product_category.dart';
import '../repositories/marketplace_repository.dart';

class GetCategories { const GetCategories(this._repository); final MarketplaceRepository _repository; Future<List<ProductCategory>> call() => _repository.getCategories(); }
