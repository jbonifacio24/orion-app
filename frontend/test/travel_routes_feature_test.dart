import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/features/travel_routes/domain/entities/travel_route.dart';
import 'package:motohub/features/travel_routes/domain/repositories/travel_routes_repository.dart';
import 'package:motohub/features/travel_routes/presentation/cubit/travel_routes_cubit.dart';

void main() {
  test('travel routes cubit removes a deleted route from the list', () async {
    final route = _route('route-1');
    final repository = _FakeTravelRoutesRepository([route]);
    final cubit = TravelRoutesCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();

    expect(await cubit.delete(route), isTrue);
    expect(cubit.state.items, isEmpty);
    expect(repository.deletedId, route.id);
  });
}

TravelRoute _route(String id) => TravelRoute(
      id: id,
      title: 'Ruta',
      description: null,
      startName: 'Origen',
      endName: 'Destino',
      startLatitude: 0,
      startLongitude: 0,
      endLatitude: 1,
      endLongitude: 1,
      pathJson: '[]',
      departureAt: DateTime.utc(2030),
      conversationId: 'conversation-1',
    );

class _FakeTravelRoutesRepository implements TravelRoutesRepository {
  _FakeTravelRoutesRepository(this.routes);
  final List<TravelRoute> routes;
  String? deletedId;

  @override
  Future<List<TravelRoute>> getPublished() async => routes;

  @override
  Future<TravelRoute> create(TravelRouteDraft draft) => throw UnimplementedError();

  @override
  Future<String> join(String routeId) => throw UnimplementedError();

  @override
  Future<void> delete(String routeId) async => deletedId = routeId;
}