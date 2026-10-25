import '../../domain/entities/product_transaction.dart';

ProductTransactionStatus _status(Object? value) => ProductTransactionStatus.values[(value as int?)?.clamp(0, 5) ?? 0];
DateTime _date(Object? value) => DateTime.tryParse(value as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

class ProductTransactionModel extends ProductTransaction {
  const ProductTransactionModel({required super.id, required super.productId, required super.sellerUserId, required super.buyerUserId, required super.offeredAmount, required super.currency, required super.paymentMethod, required super.status, required super.createdAt, required super.updatedAt, super.acceptedAt, super.paidAt, super.deliveredAt, super.completedAt, super.cancelledAt, super.cancellationReason, required super.rowVersion});

  factory ProductTransactionModel.fromJson(Map<String, dynamic> json) => ProductTransactionModel(
        id: json['id'] as String,
        productId: json['productId'] as String,
        sellerUserId: json['sellerUserId'] as String,
        buyerUserId: json['buyerUserId'] as String,
        offeredAmount: (json['offeredAmount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'PEN',
        paymentMethod: json['paymentMethod'] as String? ?? '',
        status: _status(json['status']),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
        acceptedAt: _optionalDate(json['acceptedAt']),
        paidAt: _optionalDate(json['paidAt']),
        deliveredAt: _optionalDate(json['deliveredAt']),
        completedAt: _optionalDate(json['completedAt']),
        cancelledAt: _optionalDate(json['cancelledAt']),
        cancellationReason: json['cancellationReason'] as String?,
        rowVersion: json['rowVersion'] as String? ?? '',
      );
}

DateTime? _optionalDate(Object? value) => value == null ? null : DateTime.tryParse(value as String);

class ProductTransactionReviewModel extends ProductTransactionReview {
  const ProductTransactionReviewModel({required super.id, required super.transactionId, required super.reviewerUserId, required super.reviewedUserId, required super.rating, super.comment, required super.createdAt});

  factory ProductTransactionReviewModel.fromJson(Map<String, dynamic> json) => ProductTransactionReviewModel(
        id: json['id'] as String,
        transactionId: json['productTransactionId'] as String,
        reviewerUserId: json['reviewerUserId'] as String,
        reviewedUserId: json['reviewedUserId'] as String,
        rating: json['rating'] as int? ?? 0,
        comment: json['comment'] as String?,
        createdAt: _date(json['createdAt']),
      );
}

    class ParticipantReputationModel extends ParticipantReputation {
      const ParticipantReputationModel({required super.userId, required super.averageRating, required super.ratingCount, required super.successfulSales, required super.successfulPurchases});

      factory ParticipantReputationModel.fromJson(Map<String, dynamic> json) => ParticipantReputationModel(
        userId: json['userId'] as String,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
        ratingCount: json['ratingCount'] as int? ?? 0,
        successfulSales: json['successfulSales'] as int? ?? 0,
        successfulPurchases: json['successfulPurchases'] as int? ?? 0,
      );
    }

    class ProductTransactionReputationModel extends ProductTransactionReputation {
      const ProductTransactionReputationModel({required super.buyer, required super.seller});

      factory ProductTransactionReputationModel.fromJson(Map<String, dynamic> json) => ProductTransactionReputationModel(
        buyer: ParticipantReputationModel.fromJson(json['buyer'] as Map<String, dynamic>),
        seller: ParticipantReputationModel.fromJson(json['seller'] as Map<String, dynamic>),
      );
    }

class CreateTransactionRequestModel {
  const CreateTransactionRequestModel({required this.offeredAmount, required this.currency, required this.paymentMethod});
  final double offeredAmount;
  final String currency;
  final String paymentMethod;
  Map<String, dynamic> toJson() => {'offeredAmount': offeredAmount, 'currency': currency, 'paymentMethod': paymentMethod};
}
