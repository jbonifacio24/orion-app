class Workshop {
  const Workshop({required this.id, required this.name, required this.description, required this.address, required this.city, required this.latitude, required this.longitude, required this.averageRating, required this.reviewCount});

  final String id;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double? averageRating;
  final int reviewCount;
}