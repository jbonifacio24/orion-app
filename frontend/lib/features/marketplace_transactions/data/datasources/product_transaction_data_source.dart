import 'package:dio/dio.dart';

import '../models/product_transaction_models.dart';

class ProductTransactionDataSource {
  const ProductTransactionDataSource(this._dio);
  final Dio _dio;

  Future<List<ProductTransactionModel>> getMine() async {
    final response = await _dio.get<List<dynamic>>('/transactions');
    return (response.data ?? const []).map((item) => ProductTransactionModel.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<ProductTransactionModel> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/transactions/$id');
    return ProductTransactionModel.fromJson(response.data!);
  }

  Future<ProductTransactionModel> create(String productId, CreateTransactionRequestModel request) async {
    final response = await _dio.post<Map<String, dynamic>>('/products/$productId/transactions', data: request.toJson());
    return ProductTransactionModel.fromJson(response.data!);
  }

  Future<ProductTransactionModel> changeStatus(String id, String action, {String? reason}) async {
    final response = await _dio.post<Map<String, dynamic>>('/transactions/$id/$action', data: action == 'cancel' ? {'cancellationReason': reason} : null);
    return ProductTransactionModel.fromJson(response.data!);
  }

  Future<List<ProductTransactionReviewModel>> getReviews(String id) async {
    final response = await _dio.get<List<dynamic>>('/transactions/$id/reviews');
    return (response.data ?? const []).map((item) => ProductTransactionReviewModel.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<ProductTransactionReputationModel> getReputation(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/transactions/$id/reputation');
    return ProductTransactionReputationModel.fromJson(response.data!);
  }

  Future<ProductTransactionReviewModel> addReview(String id, int rating, String? comment) async {
    final response = await _dio.post<Map<String, dynamic>>('/transactions/$id/reviews', data: {'rating': rating, 'comment': comment});
    return ProductTransactionReviewModel.fromJson(response.data!);
  }
}
