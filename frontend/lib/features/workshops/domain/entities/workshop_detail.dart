import 'workshop.dart';
import 'workshop_review.dart';
import 'workshop_schedule.dart';
import 'workshop_service.dart';

class WorkshopDetail extends Workshop {
  const WorkshopDetail({required super.id, required super.name, required super.description, required super.address, required super.city, required super.latitude, required super.longitude, required super.averageRating, required super.reviewCount, required this.phoneNumber, required this.email, required this.verifiedAt, required this.schedules, required this.services, required this.reviews});

  final String? phoneNumber;
  final String? email;
  final DateTime? verifiedAt;
  final List<WorkshopSchedule> schedules;
  final List<WorkshopService> services;
  final List<WorkshopReview> reviews;
}