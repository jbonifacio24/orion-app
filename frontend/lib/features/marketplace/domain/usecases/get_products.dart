import '../entities/paged_products.dart';
import '../entities/product_filters.dart';
import '../repositories/marketplace_repository.dart';

class GetProducts { const GetProducts(this._repository); final MarketplaceRepository _repository; Future<PagedProducts> call(ProductFilters filters, {int page = 1}) => _repository.getProducts(filters, page: page); }
