class WorkshopFilters {
  const WorkshopFilters({this.search = '', this.city = ''});

  final String search;
  final String city;

  WorkshopFilters copyWith({String? search, String? city}) => WorkshopFilters(search: search ?? this.search, city: city ?? this.city);

  Map<String, dynamic> toQuery({required int page, int pageSize = 20}) => {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (city.trim().isNotEmpty) 'city': city.trim(),
        'page': page,
        'pageSize': pageSize,
      };
}