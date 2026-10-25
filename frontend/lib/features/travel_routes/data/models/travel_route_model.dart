import '../../domain/entities/travel_route.dart';

class TravelRouteModel extends TravelRoute {
  const TravelRouteModel({
    required super.id,
    required super.title,
    required super.description,
    required super.startName,
    required super.endName,
    required super.startLatitude,
    required super.startLongitude,
    required super.endLatitude,
    required super.endLongitude,
    required super.pathJson,
    required super.departureAt,
    required super.conversationId,
  });

  factory TravelRouteModel.fromJson(Map<String, dynamic> json) => TravelRouteModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        startName: json['startName'] as String? ?? '',
        endName: json['endName'] as String? ?? '',
        startLatitude: (json['startLatitude'] as num).toDouble(),
        startLongitude: (json['startLongitude'] as num).toDouble(),
        endLatitude: (json['endLatitude'] as num).toDouble(),
        endLongitude: (json['endLongitude'] as num).toDouble(),
        pathJson: json['pathJson'] as String? ?? '[]',
        departureAt: DateTime.parse(json['departureAt'] as String).toLocal(),
        conversationId: json['conversationId'] as String,
      );
}

class JoinTravelRouteModel {
  const JoinTravelRouteModel(this.conversationId);

  factory JoinTravelRouteModel.fromJson(Map<String, dynamic> json) => JoinTravelRouteModel(json['conversationId'] as String);

  final String conversationId;
}