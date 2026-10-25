import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product_transaction.dart';
import '../../domain/repositories/product_transaction_repository.dart';
import '../datasources/product_transaction_data_source.dart';
import '../models/product_transaction_models.dart';

class ProductTransactionRepositoryImpl implements ProductTransactionRepository {
  const ProductTransactionRepositoryImpl(this._dataSource);
  final ProductTransactionDataSource _dataSource;

  @override
  Future<List<ProductTransaction>> getMine() => _map(_dataSource.getMine);
  @override
  Future<ProductTransaction> getById(String id) => _map(() => _dataSource.getById(id));
  @override
  Future<ProductTransaction> create(String productId, {required double offeredAmount, required String currency, required String paymentMethod}) => _map(() => _dataSource.create(productId, CreateTransactionRequestModel(offeredAmount: offeredAmount, currency: currency, paymentMethod: paymentMethod)));
  @override
  Future<ProductTransaction> changeStatus(String id, String action, {String? reason}) => _map(() => _dataSource.changeStatus(id, action, reason: reason));
  @override
  Future<List<ProductTransactionReview>> getReviews(String id) => _map(() => _dataSource.getReviews(id));
  @override
  Future<ProductTransactionReputation> getReputation(String id) => _map(() => _dataSource.getReputation(id));
  @override
  Future<ProductTransactionReview> addReview(String id, {required int rating, String? comment}) => _map(() => _dataSource.addReview(id, rating, comment));

  Future<T> _map<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
