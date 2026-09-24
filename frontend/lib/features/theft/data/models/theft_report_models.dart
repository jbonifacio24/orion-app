import '../../../../core/error/app_failure.dart';
import '../../domain/entities/paged_theft_reports.dart';
import '../../domain/entities/theft_report.dart';

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw SerializationFailure('El campo $key no es válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final date = DateTime.tryParse(value);
    if (date != null) return date;
  }
  throw SerializationFailure('La fecha $key no es válida.');
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) => json[key] == null ? null : _requiredDate(json, key);

class TheftReportModel extends TheftReport {
  const TheftReportModel({
    required super.id,
    required super.title,
    required super.description,
    required super.theftDate,
    required super.status,
    required super.createdAt,
    super.motorcycleId,
    super.brand,
    super.model,
    super.licensePlate,
    super.vin,
    super.color,
    super.theftLocation,
    super.latitude,
    super.longitude,
    super.resolvedAt,
  });

  factory TheftReportModel.fromJson(Map<String, dynamic> json) {
    try {
      return TheftReportModel(
        id: _requiredString(json, 'id'),
        title: _requiredString(json, 'title'),
        description: _requiredString(json, 'description'),
        theftDate: _requiredDate(json, 'theftDate'),
        status: theftReportStatusFromJson(_requiredString(json, 'status')),
        createdAt: _requiredDate(json, 'createdAt'),
        motorcycleId: json['motorcycleId'] as String?,
        brand: json['brand'] as String?,
        model: json['model'] as String?,
        licensePlate: json['licensePlate'] as String?,
        vin: (json['vinMasked'] ?? json['vin']) as String?,
        color: json['color'] as String?,
        theftLocation: json['theftLocation'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        resolvedAt: _optionalDate(json, 'resolvedAt'),
      );
    } on SerializationFailure {
      rethrow;
    } on FormatException {
      throw const SerializationFailure('El estado del reporte no es válido.');
    }
  }
}

class PagedTheftReportsModel extends PagedTheftReports {
  const PagedTheftReportsModel({required super.items, required super.page, required super.pageSize, required super.totalCount, required super.totalPages});

  factory PagedTheftReportsModel.fromJson(Map<String, dynamic> json) => PagedTheftReportsModel(
        items: (json['items'] as List<dynamic>? ?? const []).map((item) => TheftReportModel.fromJson(item as Map<String, dynamic>)).toList(growable: false),
        page: json['page'] as int? ?? 1,
        pageSize: json['pageSize'] as int? ?? 20,
        totalCount: json['totalCount'] as int? ?? 0,
        totalPages: json['totalPages'] as int? ?? 0,
      );
}

class CreateTheftReportRequestModel {
  const CreateTheftReportRequestModel(this.input);
  final CreateTheftReportInput input;

  Map<String, dynamic> toJson() => {
        'title': input.title,
        'description': input.description,
        'theftDate': input.theftDate.toUtc().toIso8601String(),
        if (input.motorcycleId != null) 'motorcycleId': input.motorcycleId,
        if (input.motorcycleId == null && input.brand != null) 'brand': input.brand,
        if (input.motorcycleId == null && input.model != null) 'model': input.model,
        if (input.motorcycleId == null && input.licensePlate != null) 'licensePlate': input.licensePlate,
        if (input.motorcycleId == null && input.vin != null) 'vin': input.vin,
        if (input.motorcycleId == null && input.color != null) 'color': input.color,
        if (input.theftLocation != null) 'theftLocation': input.theftLocation,
        if (input.latitude != null) 'latitude': input.latitude,
        if (input.longitude != null) 'longitude': input.longitude,
      };
}

class UpdateTheftReportStatusRequestModel {
  const UpdateTheftReportStatusRequestModel(this.status);
  final TheftReportStatus status;
  Map<String, dynamic> toJson() => {'status': status.value};
}