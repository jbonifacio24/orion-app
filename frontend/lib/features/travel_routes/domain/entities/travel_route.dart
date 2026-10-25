class TravelRoute {
  const TravelRoute({
    required this.id,
    required this.title,
    required this.description,
    required this.startName,
    required this.endName,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.pathJson,
    required this.departureAt,
    required this.conversationId,
  });

  final String id;
  final String title;
  final String? description;
  final String startName;
  final String endName;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String pathJson;
  final DateTime departureAt;
  final String conversationId;
}

class TravelRouteDraft {
  const TravelRouteDraft({
    required this.title,
    required this.description,
    required this.startName,
    required this.endName,
    required this.startLatitude,
    required this.startLongitude,
    required this.endLatitude,
    required this.endLongitude,
    required this.pathJson,
    required this.departureAt,
  });

  final String title;
  final String? description;
  final String startName;
  final String endName;
  final double startLatitude;
  final double startLongitude;
  final double endLatitude;
  final double endLongitude;
  final String pathJson;
  final DateTime departureAt;
}