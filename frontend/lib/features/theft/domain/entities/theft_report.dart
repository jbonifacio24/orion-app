import 'package:equatable/equatable.dart';

enum TheftReportStatus { reported, investigating, recovered, closed }

TheftReportStatus theftReportStatusFromJson(String value) => switch (value.toLowerCase()) {
      'reported' => TheftReportStatus.reported,
      'investigating' => TheftReportStatus.investigating,
      'recovered' => TheftReportStatus.recovered,
      'closed' => TheftReportStatus.closed,
      _ => throw FormatException('Estado de reporte inválido: $value'),
    };

extension TheftReportStatusX on TheftReportStatus {
  String get value => switch (this) {
        TheftReportStatus.reported => 'Reported',
        TheftReportStatus.investigating => 'Investigating',
        TheftReportStatus.recovered => 'Recovered',
        TheftReportStatus.closed => 'Closed',
      };

  String get label => switch (this) {
        TheftReportStatus.reported => 'Reportado',
        TheftReportStatus.investigating => 'En investigación',
        TheftReportStatus.recovered => 'Recuperado',
        TheftReportStatus.closed => 'Cerrado',
      };

  bool get isActive => this == TheftReportStatus.reported || this == TheftReportStatus.investigating;
}

class TheftReport extends Equatable {
  const TheftReport({
    required this.id,
    required this.title,
    required this.description,
    required this.theftDate,
    required this.status,
    required this.createdAt,
    this.motorcycleId,
    this.brand,
    this.model,
    this.licensePlate,
    this.vin,
    this.color,
    this.theftLocation,
    this.latitude,
    this.longitude,
    this.resolvedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime theftDate;
  final TheftReportStatus status;
  final DateTime createdAt;
  final String? motorcycleId;
  final String? brand;
  final String? model;
  final String? licensePlate;
  final String? vin;
  final String? color;
  final String? theftLocation;
  final double? latitude;
  final double? longitude;
  final DateTime? resolvedAt;

  String get motorcycleName => [brand, model].whereType<String>().where((item) => item.trim().isNotEmpty).join(' ');

  @override
  List<Object?> get props => [id, title, description, theftDate, status, createdAt, motorcycleId, brand, model, licensePlate, vin, color, theftLocation, latitude, longitude, resolvedAt];
}

class CreateTheftReportInput extends Equatable {
  const CreateTheftReportInput({
    required this.title,
    required this.description,
    required this.theftDate,
    this.motorcycleId,
    this.brand,
    this.model,
    this.licensePlate,
    this.vin,
    this.color,
    this.theftLocation,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String description;
  final DateTime theftDate;
  final String? motorcycleId;
  final String? brand;
  final String? model;
  final String? licensePlate;
  final String? vin;
  final String? color;
  final String? theftLocation;
  final double? latitude;
  final double? longitude;

  @override
  List<Object?> get props => [title, description, theftDate, motorcycleId, brand, model, licensePlate, vin, color, theftLocation, latitude, longitude];
}