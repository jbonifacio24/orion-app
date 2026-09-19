import '../entities/paged_products.dart';
import '../entities/product_filters.dart';
import '../repositories/marketplace_repository.dart';

class GetMyProducts { const GetMyProducts(this._repository); final MarketplaceRepository _repository; Future<PagedProducts> call(ProductFilters filters, {int page = 1}) => _repository.getMyProducts(filters, page: page); }
