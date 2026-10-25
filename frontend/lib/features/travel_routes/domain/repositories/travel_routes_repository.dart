import '../entities/travel_route.dart';

abstract interface class TravelRoutesRepository {
  Future<List<TravelRoute>> getPublished();
  Future<TravelRoute> create(TravelRouteDraft draft);
  Future<String> join(String routeId);
  Future<void> delete(String routeId);
}