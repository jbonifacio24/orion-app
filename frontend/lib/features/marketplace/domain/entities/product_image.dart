class ProductImage {
  const ProductImage({required this.id, required this.url, required this.thumbnailUrl, required this.displayOrder, required this.isPrimary});

  final String id;
  final String url;
  final String? thumbnailUrl;
  final int displayOrder;
  final bool isPrimary;
}
