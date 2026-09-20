class WorkshopService {
  const WorkshopService({required this.id, required this.name, required this.description, required this.price, required this.durationMinutes});

  final String id;
  final String name;
  final String? description;
  final double? price;
  final int? durationMinutes;
}