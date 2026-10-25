import '../entities/product_transaction.dart';
import '../repositories/product_transaction_repository.dart';

class GetMyProductTransactions {
  const GetMyProductTransactions(this._repository);
  final ProductTransactionRepository _repository;
  Future<List<ProductTransaction>> call() => _repository.getMine();
}

class GetProductTransaction {
  const GetProductTransaction(this._repository);
  final ProductTransactionRepository _repository;
  Future<ProductTransaction> call(String id) => _repository.getById(id);
}

class CreateProductTransaction {
  const CreateProductTransaction(this._repository);
  final ProductTransactionRepository _repository;
  Future<ProductTransaction> call(String productId, {required double offeredAmount, required String currency, required String paymentMethod}) => _repository.create(productId, offeredAmount: offeredAmount, currency: currency, paymentMethod: paymentMethod);
}

class ChangeProductTransactionStatus {
  const ChangeProductTransactionStatus(this._repository);
  final ProductTransactionRepository _repository;
  Future<ProductTransaction> call(String id, String action, {String? reason}) => _repository.changeStatus(id, action, reason: reason);
}

class ProductTransactionReviews {
  const ProductTransactionReviews(this._repository);
  final ProductTransactionRepository _repository;
  Future<List<ProductTransactionReview>> get(String id) => _repository.getReviews(id);
  Future<ProductTransactionReview> add(String id, {required int rating, String? comment}) => _repository.addReview(id, rating: rating, comment: comment);
}

class GetProductTransactionReputation {
  const GetProductTransactionReputation(this._repository);
  final ProductTransactionRepository _repository;
  Future<ProductTransactionReputation> call(String id) => _repository.getReputation(id);
}
