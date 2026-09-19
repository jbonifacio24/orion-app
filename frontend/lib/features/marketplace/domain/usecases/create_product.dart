import '../entities/product.dart';
import '../repositories/marketplace_repository.dart';

class CreateProduct {
	const CreateProduct(this._repository);
	final MarketplaceRepository _repository;

	Future<Product> call({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) => _repository.createProduct(categoryId: categoryId, name: name, description: description, price: price, currency: currency, stockQuantity: stockQuantity, condition: condition, location: location);
}
