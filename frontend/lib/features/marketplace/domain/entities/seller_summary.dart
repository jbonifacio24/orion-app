class SellerSummary {
  const SellerSummary({required this.id, required this.userName, required this.displayName, required this.profileImageUrl, this.successfulSales = 0, this.averageRating = 0, this.ratingCount = 0});

  final String id;
  final String userName;
  final String? displayName;
  final String? profileImageUrl;
  final int successfulSales;
  final double averageRating;
  final int ratingCount;
}
