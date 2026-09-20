class WorkshopSchedule {
  const WorkshopSchedule({required this.id, required this.dayOfWeek, required this.openTime, required this.closeTime, required this.isClosed});

  final String id;
  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;
}