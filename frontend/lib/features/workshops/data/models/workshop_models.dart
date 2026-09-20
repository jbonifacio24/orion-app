import '../../../../core/error/app_failure.dart';
import '../../domain/entities/paged_workshops.dart';
import '../../domain/entities/workshop.dart';
import '../../domain/entities/workshop_detail.dart';
import '../../domain/entities/workshop_review.dart';
import '../../domain/entities/workshop_schedule.dart';
import '../../domain/entities/workshop_service.dart';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw SerializationFailure('La fecha $key no es válida.');
}

class WorkshopModel extends Workshop {
  const WorkshopModel({required super.id, required super.name, required super.description, required super.address, required super.city, required super.latitude, required super.longitude, required super.averageRating, required super.reviewCount});

  factory WorkshopModel.fromJson(Map<String, dynamic> json) => WorkshopModel(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        description: json['description'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        reviewCount: json['reviewCount'] as int? ?? 0,
      );
}

class WorkshopScheduleModel extends WorkshopSchedule {
  const WorkshopScheduleModel({required super.id, required super.dayOfWeek, required super.openTime, required super.closeTime, required super.isClosed});

  factory WorkshopScheduleModel.fromJson(Map<String, dynamic> json) => WorkshopScheduleModel(
        id: _requiredString(json, 'id'),
        dayOfWeek: json['dayOfWeek'] as int? ?? 0,
        openTime: json['openTime'] as String?,
        closeTime: json['closeTime'] as String?,
        isClosed: json['isClosed'] as bool? ?? false,
      );
}

class WorkshopServiceModel extends WorkshopService {
  const WorkshopServiceModel({required super.id, required super.name, required super.description, required super.price, required super.durationMinutes});

  factory WorkshopServiceModel.fromJson(Map<String, dynamic> json) => WorkshopServiceModel(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        description: json['description'] as String?,
        price: (json['price'] as num?)?.toDouble(),
        durationMinutes: json['durationMinutes'] as int?,
      );
}

class WorkshopReviewModel extends WorkshopReview {
  const WorkshopReviewModel({required super.id, required super.rating, required super.comment, required super.createdAt});

  factory WorkshopReviewModel.fromJson(Map<String, dynamic> json) => WorkshopReviewModel(
        id: _requiredString(json, 'id'),
        rating: json['rating'] as int? ?? 0,
        comment: json['comment'] as String?,
        createdAt: _requiredDate(json, 'createdAt'),
      );
}

class PagedWorkshopsModel extends PagedWorkshops {
  const PagedWorkshopsModel({required super.items, required super.page, required super.pageSize, required super.totalCount, required super.totalPages});

  factory PagedWorkshopsModel.fromJson(Map<String, dynamic> json) => PagedWorkshopsModel(
        items: (json['items'] as List<dynamic>? ?? const []).map((item) => WorkshopModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalCount: json['totalCount'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
      );
}

class WorkshopDetailModel extends WorkshopDetail {
  const WorkshopDetailModel({required super.id, required super.name, required super.description, required super.address, required super.city, required super.latitude, required super.longitude, required super.averageRating, required super.reviewCount, required super.phoneNumber, required super.email, required super.verifiedAt, required super.schedules, required super.services, required super.reviews});

  factory WorkshopDetailModel.fromJson(Map<String, dynamic> json) => WorkshopDetailModel(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        description: json['description'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        verifiedAt: json['verifiedAt'] == null ? null : _requiredDate(json, 'verifiedAt'),
        schedules: (json['schedules'] as List<dynamic>? ?? const []).map((item) => WorkshopScheduleModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        services: (json['services'] as List<dynamic>? ?? const []).map((item) => WorkshopServiceModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        reviews: (json['reviews'] as List<dynamic>? ?? const []).map((item) => WorkshopReviewModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        reviewCount: json['reviewCount'] as int? ?? 0,
      );
}