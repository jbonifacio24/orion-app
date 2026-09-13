import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/motorcycles/data/models/motorcycle_models.dart';
import 'package:motohub/features/motorcycles/domain/entities/motorcycle.dart';
import 'package:motohub/features/motorcycles/domain/repositories/motorcycle_repository.dart';
import 'package:motohub/features/motorcycles/domain/usecases/create_motorcycle.dart';
import 'package:motohub/features/motorcycles/domain/usecases/delete_motorcycle.dart';
import 'package:motohub/features/motorcycles/domain/usecases/get_motorcycle_by_id.dart';
import 'package:motohub/features/motorcycles/domain/usecases/get_motorcycles.dart';
import 'package:motohub/features/motorcycles/domain/usecases/update_motorcycle.dart';
import 'package:motohub/features/motorcycles/presentation/cubit/motorcycle_cubit.dart';
import 'package:motohub/features/motorcycles/presentation/widgets/motorcycle_card.dart';

void main() {
  test('motorcycle model maps images and primary state', () {
    final motorcycle = MotorcycleModel.fromJson({'id': '1', 'brand': 'Honda', 'model': 'CB', 'year': 2020, 'isPrimary': true, 'images': [{'id': 'i1', 'url': 'https://example/image.jpg', 'thumbnailUrl': null, 'displayOrder': 0, 'isPrimary': true}]});
    expect(motorcycle, isA<Motorcycle>());
    expect(motorcycle.isPrimary, isTrue);
    expect(motorcycle.images.single.isPrimary, isTrue);
  });

  test('motorcycle request does not contain ownership fields', () {
    final json = const MotorcycleRequestModel(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false).toJson();
    expect(json.keys, hasLength(9));
    expect(json, isNot(contains('ownerUserId')));
    expect(json, isNot(contains('userId')));
  });

  test('motorcycle cubit synchronizes list after create and delete', () async {
    final repository = _MotorcycleRepository();
    final cubit = MotorcycleCubit(GetMotorcycles(repository), GetMotorcycleById(repository), CreateMotorcycle(repository), UpdateMotorcycle(repository), DeleteMotorcycle(repository));
    addTearDown(cubit.close);
    await cubit.loadMotorcycles();
    expect(cubit.state.motorcycles, isEmpty);
    await cubit.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: true);
    expect(cubit.state.motorcycles, hasLength(1));
    final id = cubit.state.motorcycles.single.id;
    expect(await cubit.delete(id), isTrue);
    expect(cubit.state.motorcycles, isEmpty);
  });

  test('create remains successful when list refresh fails', () async {
    final repository = _MotorcycleRepository()..failRefresh = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    final result = await cubit.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: true);
    expect(result, isNotNull);
    expect(cubit.state.syncWarning, isNotNull);
  });

  test('update remains successful when list refresh fails', () async {
    final repository = _MotorcycleRepository();
    final item = await repository.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false);
    repository.failRefresh = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    final result = await cubit.update(id: item.id, brand: 'Yamaha', model: 'MT', year: 2021, isPrimary: false);
    expect(result, isNotNull);
    expect(cubit.state.syncWarning, isNotNull);
  });

  test('delete remains successful when list refresh fails', () async {
    final repository = _MotorcycleRepository();
    final item = await repository.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false);
    repository.failRefresh = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    expect(await cubit.delete(item.id), isTrue);
    expect(cubit.state.syncWarning, isNotNull);
  });

  test('a real mutation failure remains a failure', () async {
    final repository = _MotorcycleRepository()..failMutation = true;
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    expect(await cubit.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false), isNull);
    expect(cubit.state.message, 'mutation failed');
  });

  test('concurrent create calls execute only one mutation', () async {
    final repository = _MotorcycleRepository()..mutationDelay = const Duration(milliseconds: 10);
    final cubit = _cubit(repository);
    addTearDown(cubit.close);
    final results = await Future.wait([
      cubit.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false),
      cubit.create(brand: 'Honda', model: 'CB', year: 2020, isPrimary: false),
    ]);
    expect(results.whereType<Motorcycle>(), hasLength(1));
    expect(repository.createCalls, 1);
  });

  testWidgets('motorcycle image preview shows placeholder without an image', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MotorcycleImagePreview()));
    expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
  });

  testWidgets('motorcycle image preview builds a network image when available', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MotorcycleImagePreview(url: 'https://example.com/motorcycle.jpg')));
    expect(find.byType(Image), findsOneWidget);
  });
}

MotorcycleCubit _cubit(_MotorcycleRepository repository) => MotorcycleCubit(GetMotorcycles(repository), GetMotorcycleById(repository), CreateMotorcycle(repository), UpdateMotorcycle(repository), DeleteMotorcycle(repository));

class _MotorcycleRepository implements MotorcycleRepository {
  final List<Motorcycle> items = [];
  int nextId = 0;
  bool failRefresh = false;
  bool failMutation = false;
  Duration mutationDelay = Duration.zero;
  int createCalls = 0;

  @override
  Future<List<Motorcycle>> getAll() async {
    if (failRefresh) throw const NetworkFailure('refresh failed');
    return List.unmodifiable(items);
  }

  @override
  Future<Motorcycle> getById(String id) async => items.singleWhere((item) => item.id == id);

  @override
  Future<Motorcycle> create({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async {
    createCalls++;
    if (mutationDelay > Duration.zero) await Future<void>.delayed(mutationDelay);
    if (failMutation) throw const NetworkFailure('mutation failed');
    final item = Motorcycle(id: '${++nextId}', brand: brand, model: model, year: year, isPrimary: isPrimary);
    items.add(item);
    return item;
  }

  @override
  Future<Motorcycle> update({required String id, required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async => Motorcycle(id: id, brand: brand, model: model, year: year, isPrimary: isPrimary);

  @override
  Future<void> delete(String id) async => items.removeWhere((item) => item.id == id);
}
