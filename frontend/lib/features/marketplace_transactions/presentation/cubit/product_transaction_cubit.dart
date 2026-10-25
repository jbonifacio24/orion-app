import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product_transaction.dart';
import '../../domain/usecases/product_transaction_usecases.dart';

class ProductTransactionState {
  const ProductTransactionState({this.transaction, this.items = const [], this.reviews = const [], this.reputation, this.loading = false, this.submitting = false, this.error});
  final ProductTransaction? transaction;
  final List<ProductTransaction> items;
  final List<ProductTransactionReview> reviews;
  final ProductTransactionReputation? reputation;
  final bool loading;
  final bool submitting;
  final String? error;

  ProductTransactionState copyWith({ProductTransaction? transaction, List<ProductTransaction>? items, List<ProductTransactionReview>? reviews, ProductTransactionReputation? reputation, bool? loading, bool? submitting, String? error, bool clearError = false}) => ProductTransactionState(transaction: transaction ?? this.transaction, items: items ?? this.items, reviews: reviews ?? this.reviews, reputation: reputation ?? this.reputation, loading: loading ?? this.loading, submitting: submitting ?? this.submitting, error: clearError ? null : error ?? this.error);
}

class ProductTransactionCubit extends Cubit<ProductTransactionState> {
  ProductTransactionCubit(this._getMine, this._getById, this._create, this._changeStatus, this._reviews, this._getReputation) : super(const ProductTransactionState());
  final GetMyProductTransactions _getMine;
  final GetProductTransaction _getById;
  final CreateProductTransaction _create;
  final ChangeProductTransactionStatus _changeStatus;
  final ProductTransactionReviews _reviews;
  final GetProductTransactionReputation _getReputation;

  Future<void> loadMine() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      emit(state.copyWith(items: await _getMine(), loading: false));
    } catch (error) {
      emit(state.copyWith(loading: false, error: ErrorMapper.from(error).message));
    }
  }

  Future<void> load(String id) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final transaction = await _getById(id);
      final reviews = await _reviews.get(id);
      final reputation = await _getReputation(id);
      emit(state.copyWith(transaction: transaction, reviews: reviews, reputation: reputation, loading: false));
    } catch (error) {
      emit(state.copyWith(loading: false, error: ErrorMapper.from(error).message));
    }
  }

  Future<bool> create(String productId, {required double amount, required String currency, required String paymentMethod}) => _run(() async {
        final transaction = await _create(productId, offeredAmount: amount, currency: currency, paymentMethod: paymentMethod);
        emit(state.copyWith(transaction: transaction, submitting: false, clearError: true));
      });

  Future<bool> changeStatus(String action, {String? reason}) => _run(() async {
        final current = state.transaction;
        if (current == null) return;
        final transaction = await _changeStatus(current.id, action, reason: reason);
        emit(state.copyWith(transaction: transaction, submitting: false, clearError: true));
      });

  Future<bool> addReview({required int rating, String? comment}) => _run(() async {
        final current = state.transaction;
        if (current == null) return;
        final review = await _reviews.add(current.id, rating: rating, comment: comment);
        ProductTransactionReputation? reputation;
        try {
          reputation = await _getReputation(current.id);
        } catch (_) {}
        emit(state.copyWith(reviews: [...state.reviews, review], reputation: reputation, submitting: false, clearError: true));
      });

  Future<bool> _run(Future<void> Function() action) async {
    if (state.submitting) return false;
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await action();
      return true;
    } catch (error) {
      emit(state.copyWith(submitting: false, error: ErrorMapper.from(error).message));
      return false;
    }
  }
}
