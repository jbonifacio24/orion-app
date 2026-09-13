class MotorcycleImage {
  const MotorcycleImage({
    required this.id,
    required this.url,
    required this.displayOrder,
    required this.isPrimary,
    this.thumbnailUrl,
  });

  final String id;
  final String url;
  final String? thumbnailUrl;
  final int displayOrder;
  final bool isPrimary;
}
