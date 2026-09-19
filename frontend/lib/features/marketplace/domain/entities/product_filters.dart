import 'product.dart';

class ProductFilters {
  const ProductFilters({this.search = '', this.categoryId, this.minPrice, this.maxPrice, this.condition, this.sort = 'newest'});

  final String search;
  final String? categoryId;
  final double? minPrice;
  final double? maxPrice;
  final ProductCondition? condition;
  final String sort;

  ProductFilters copyWith({String? search, String? categoryId, bool clearCategory = false, double? minPrice, bool clearMinPrice = false, double? maxPrice, bool clearMaxPrice = false, ProductCondition? condition, bool clearCondition = false, String? sort}) => ProductFilters(
        search: search ?? this.search,
        categoryId: clearCategory ? null : categoryId ?? this.categoryId,
        minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
        maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
        condition: clearCondition ? null : condition ?? this.condition,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toQuery({required int page, int pageSize = 20}) => {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (categoryId != null) 'categoryId': categoryId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (condition != null) 'condition': condition!.index,
        if (sort.isNotEmpty) 'sort': sort,
        'page': page,
        'pageSize': pageSize,
      };
}
