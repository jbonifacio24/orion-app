import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/workshops/data/models/workshop_models.dart';
import 'package:motohub/features/workshops/domain/entities/paged_workshops.dart';
import 'package:motohub/features/workshops/domain/entities/workshop.dart';
import 'package:motohub/features/workshops/domain/entities/workshop_detail.dart';
import 'package:motohub/features/workshops/domain/entities/workshop_filters.dart';
import 'package:motohub/features/workshops/domain/repositories/workshop_repository.dart';
import 'package:motohub/features/workshops/domain/usecases/get_workshop_detail.dart';
import 'package:motohub/features/workshops/domain/usecases/get_workshops.dart';
import 'package:motohub/features/workshops/presentation/cubit/workshop_detail_cubit.dart';
import 'package:motohub/features/workshops/presentation/cubit/workshops_cubit.dart';
import 'package:motohub/features/workshops/presentation/widgets/workshop_card.dart';

void main() {
  test('maps list and detail JSON including nullable numeric and temporal fields', () {
    final list = PagedWorkshopsModel.fromJson({
      'items': [
        {'id': '1', 'name': 'Taller', 'latitude': -12, 'longitude': -77.042793, 'averageRating': null, 'reviewCount': 0},
      ],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });
    final detail = WorkshopDetailModel.fromJson({
      'id': '1',
      'name': 'Taller',
      'description': null,
      'phoneNumber': null,
      'email': null,
      'address': null,
      'city': null,
      'latitude': -12.0,
      'longitude': -77,
      'verifiedAt': '2026-09-20T12:00:00+00:00',
      'schedules': [{'id': 's', 'dayOfWeek': 0, 'openTime': '09:00:00', 'closeTime': '18:00:00', 'isClosed': false}],
      'services': [{'id': 'v', 'name': 'Servicio', 'price': 20, 'durationMinutes': null}],
      'reviews': [{'id': 'r', 'rating': 5, 'comment': null, 'createdAt': '2026-09-20T12:00:00+00:00'}],
      'averageRating': 5,
      'reviewCount': 1,
    });

    expect(list.items.single.latitude, -12.0);
    expect(list.items.single.averageRating, isNull);
    expect(detail.verifiedAt, isNotNull);
    expect(detail.schedules.single.openTime, '09:00:00');
    expect(detail.services.single.price, 20.0);
    expect(detail.reviews.single.createdAt.isUtc, isTrue);
  });

  test('invalid required JSON becomes SerializationFailure', () {
    expect(() => WorkshopModel.fromJson({'id': '1'}), throwsA(isA<SerializationFailure>()));
    expect(() => WorkshopReviewModel.fromJson({'id': 'r', 'rating': 5, 'createdAt': 'invalid'}), throwsA(isA<SerializationFailure>()));
  });

  test('filters omit blank values and preserve pagination contract', () {
    const filters = WorkshopFilters(search: '  ', city: ' Lima ');
    expect(filters.toQuery(page: 2), {'city': 'Lima', 'page': 2, 'pageSize': 20});
  });

  test('coordinate validation accepts only valid pairs', () {
    expect(validWorkshopCoordinates(-90, 180), isTrue);
    expect(validWorkshopCoordinates(null, 0), isFalse);
    expect(validWorkshopCoordinates(-90.1, 0), isFalse);
    expect(validWorkshopCoordinates(0, 180.1), isFalse);
  });

  test('workshops cubit ignores stale search responses', () async {
    final first = Completer<PagedWorkshops>();
    final second = Completer<PagedWorkshops>();
    final repository = _FakeWorkshopRepository(onList: (filters, page) => filters.search == 'first' ? first.future : second.future);
    final cubit = WorkshopsCubit(GetWorkshops(repository));
    addTearDown(cubit.close);

    cubit.searchChanged('first');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    cubit.searchChanged('second');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    second.complete(_page('second'));
    await Future<void>.delayed(Duration.zero);
    first.complete(_page('first'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items.single.name, 'second');
    expect(cubit.state.filters.search, 'second');
  });

  test('load more failure preserves existing items and can retry', () async {
    var calls = 0;
    final repository = _FakeWorkshopRepository(onList: (_, page) {
      calls++;
      if (page == 2 && calls == 2) return Future.error(const NetworkFailure('offline'));
      return Future.value(_page(page == 1 ? 'first' : 'second', page: page, totalPages: 2));
    });
    final cubit = WorkshopsCubit(GetWorkshops(repository));
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.items.single.name, 'first');
    expect(cubit.state.loadingMoreFailure, isNotNull);
    await cubit.retryLoadMore();
    expect(cubit.state.items.map((item) => item.name), containsAll(<String>['first', 'second']));
  });

  test('detail cubit loads and refreshes the requested id', () async {
    final repository = _FakeWorkshopRepository(onDetail: (id) async => _detail(id));
    final cubit = WorkshopDetailCubit(GetWorkshopDetail(repository));
    addTearDown(cubit.close);

    await cubit.load('workshop-id');
    expect((cubit.state as WorkshopDetailLoaded).workshop.id, 'workshop-id');
    await cubit.refresh();
    expect((cubit.state as WorkshopDetailLoaded).workshop.id, 'workshop-id');
  });

  test('detail cubit ignores stale responses', () async {
    final first = Completer<WorkshopDetail>();
    final second = Completer<WorkshopDetail>();
    final repository = _FakeWorkshopRepository(onDetail: (id) => id == 'first' ? first.future : second.future);
    final cubit = WorkshopDetailCubit(GetWorkshopDetail(repository));
    addTearDown(cubit.close);

    final firstLoad = cubit.load('first');
    final secondLoad = cubit.load('second');
    second.complete(_detail('second'));
    await secondLoad;
    first.complete(_detail('first'));
    await firstLoad;

    expect((cubit.state as WorkshopDetailLoaded).workshop.id, 'second');
  });

  test('detail cubit ignores a pending response after close', () async {
    final pending = Completer<WorkshopDetail>();
    final repository = _FakeWorkshopRepository(onDetail: (_) => pending.future);
    final cubit = WorkshopDetailCubit(GetWorkshopDetail(repository));

    final load = cubit.load('pending');
    await cubit.close();
    pending.complete(_detail('pending'));
    await load;

    expect(cubit.isClosed, isTrue);
  });

  test('detail refresh invalidates an older load', () async {
    final first = Completer<WorkshopDetail>();
    final secondLoad = Completer<WorkshopDetail>();
    final secondRefresh = Completer<WorkshopDetail>();
    var secondCalls = 0;
    final repository = _FakeWorkshopRepository(onDetail: (id) {
      if (id == 'first') return first.future;
      secondCalls++;
      return secondCalls == 1 ? secondLoad.future : secondRefresh.future;
    });
    final cubit = WorkshopDetailCubit(GetWorkshopDetail(repository));
    addTearDown(cubit.close);

    final firstLoad = cubit.load('first');
    final secondRequest = cubit.load('second');
    secondLoad.complete(_detail('second'));
    await secondRequest;
    final refresh = cubit.refresh();
    secondRefresh.complete(_detail('second-refreshed'));
    await refresh;
    first.complete(_detail('first'));
    await firstLoad;

    expect((cubit.state as WorkshopDetailLoaded).workshop.id, 'second-refreshed');
  });
}

PagedWorkshops _page(String name, {int page = 1, int totalPages = 1}) => PagedWorkshops(items: [Workshop(id: name, name: name, description: null, address: null, city: null, latitude: null, longitude: null, averageRating: null, reviewCount: 0)], page: page, pageSize: 20, totalCount: totalPages, totalPages: totalPages);

WorkshopDetail _detail(String id) => WorkshopDetail(id: id, name: 'Taller', description: null, address: null, city: null, latitude: null, longitude: null, averageRating: null, reviewCount: 0, phoneNumber: null, email: null, verifiedAt: null, schedules: const [], services: const [], reviews: const []);

class _FakeWorkshopRepository implements WorkshopRepository {
  _FakeWorkshopRepository({this.onList, this.onDetail});
  final Future<PagedWorkshops> Function(WorkshopFilters filters, int page)? onList;
  final Future<WorkshopDetail> Function(String id)? onDetail;

  @override
  Future<PagedWorkshops> getWorkshops(WorkshopFilters filters, {int page = 1}) => onList?.call(filters, page) ?? Future.value(_page('default'));

  @override
  Future<WorkshopDetail> getWorkshopDetail(String id) => onDetail?.call(id) ?? Future.value(_detail(id));
}