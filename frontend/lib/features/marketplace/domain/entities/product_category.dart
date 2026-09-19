class ProductCategory {
  const ProductCategory({required this.id, required this.parentCategoryId, required this.name, required this.slug, required this.description, required this.displayOrder, required this.isActive});

  final String id;
  final String? parentCategoryId;
  final String name;
  final String slug;
  final String? description;
  final int displayOrder;
  final bool isActive;
}
