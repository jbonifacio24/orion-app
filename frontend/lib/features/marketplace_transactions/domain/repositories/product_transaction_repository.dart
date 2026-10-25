import '../entities/product_transaction.dart';

abstract interface class ProductTransactionRepository {
  Future<List<ProductTransaction>> getMine();
  Future<ProductTransaction> getById(String id);
  Future<ProductTransaction> create(String productId, {required double offeredAmount, required String currency, required String paymentMethod});
  Future<ProductTransaction> changeStatus(String id, String action, {String? reason});
  Future<List<ProductTransactionReview>> getReviews(String id);
  Future<ProductTransactionReputation> getReputation(String id);
  Future<ProductTransactionReview> addReview(String id, {required int rating, String? comment});
}
