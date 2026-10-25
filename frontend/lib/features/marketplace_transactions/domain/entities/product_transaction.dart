enum ProductTransactionStatus { offer, accepted, paid, delivered, completed, cancelled }

class ProductTransaction {
  const ProductTransaction({required this.id, required this.productId, required this.sellerUserId, required this.buyerUserId, required this.offeredAmount, required this.currency, required this.paymentMethod, required this.status, required this.createdAt, required this.updatedAt, this.acceptedAt, this.paidAt, this.deliveredAt, this.completedAt, this.cancelledAt, this.cancellationReason, required this.rowVersion});

  final String id;
  final String productId;
  final String sellerUserId;
  final String buyerUserId;
  final double offeredAmount;
  final String currency;
  final String paymentMethod;
  final ProductTransactionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? paidAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String rowVersion;
}

class ProductTransactionReview {
  const ProductTransactionReview({required this.id, required this.transactionId, required this.reviewerUserId, required this.reviewedUserId, required this.rating, this.comment, required this.createdAt});

  final String id;
  final String transactionId;
  final String reviewerUserId;
  final String reviewedUserId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
}

class ParticipantReputation {
  const ParticipantReputation({required this.userId, required this.averageRating, required this.ratingCount, required this.successfulSales, required this.successfulPurchases});

  final String userId;
  final double averageRating;
  final int ratingCount;
  final int successfulSales;
  final int successfulPurchases;
}

class ProductTransactionReputation {
  const ProductTransactionReputation({required this.buyer, required this.seller});

  final ParticipantReputation buyer;
  final ParticipantReputation seller;
}
