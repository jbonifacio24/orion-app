import '../repositories/marketplace_repository.dart';
import '../entities/product_detail.dart';

class GetProductDetail { const GetProductDetail(this._repository); final MarketplaceRepository _repository; Future<ProductDetail> call(String id) => _repository.getProduct(id); }
