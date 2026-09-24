import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motohub/core/router/app_router.dart';
import 'package:motohub/features/theft/data/models/theft_report_models.dart';
import 'package:motohub/features/theft/domain/entities/paged_theft_reports.dart';
import 'package:motohub/features/theft/domain/entities/theft_report.dart';
import 'package:motohub/features/theft/domain/repositories/theft_repository.dart';
import 'package:motohub/features/theft/domain/usecases/theft_report_usecases.dart';
import 'package:motohub/features/theft/presentation/cubit/my_theft_reports_cubit.dart';
import 'package:motohub/features/theft/presentation/cubit/theft_reports_cubit.dart';
import 'package:motohub/features/theft/presentation/widgets/theft_report_card.dart';

void main() {
  test('maps theft report JSON and supports masked VIN responses', () {
    final report = TheftReportModel.fromJson({
      'id': 'report-1',
      'title': 'Moto robada',
      'description': 'Se solicita información.',
      'theftDate': '2026-09-20T10:30:00Z',
      'status': 'Investigating',
      'createdAt': '2026-09-20T11:00:00Z',
      'brand': 'Honda',
      'model': 'CB 190R',
      'vinMasked': '********1234',
    });

    expect(report.status, TheftReportStatus.investigating);
    expect(report.motorcycleName, 'Honda CB 190R');
    expect(report.vin, '********1234');
  });

  test('preserves personal report pagination metadata from JSON', () {
    final page = PagedTheftReportsModel.fromJson({
      'items': [_reportJson('report-1')],
      'page': 2,
      'pageSize': 10,
      'totalCount': 15,
      'totalPages': 2,
    });

    expect(page.page, 2);
    expect(page.pageSize, 10);
    expect(page.totalCount, 15);
    expect(page.totalPages, 2);
    expect(page.items.single.id, 'report-1');
  });

  test('places literal theft report routes before the dynamic detail route', () {
    final paths = theftReportRoutes().cast<GoRoute>().map((route) => route.path).toList();

    expect(paths, ['/theft-reports', '/theft-reports/mine', '/theft-reports/create', '/theft-reports/:id']);
  });

  test('create and status requests never include authority controlled fields', () {
    final request = CreateTheftReportRequestModel(CreateTheftReportInput(
      title: 'Moto robada',
      description: 'Detalle',
      theftDate: DateTime.utc(2026, 9, 20),
      brand: 'Yamaha',
      model: 'MT-03',
      licensePlate: 'ABC-123',
    )).toJson();
    final status = const UpdateTheftReportStatusRequestModel(TheftReportStatus.recovered).toJson();

    expect(request, containsPair('brand', 'Yamaha'));
    expect(request.keys, isNot(contains('reporterUserId')));
    expect(request.keys, isNot(contains('status')));
    expect(request.keys, isNot(contains('resolvedAt')));
    expect(status, {'status': 'Recovered'});
  });

  test('public reports Cubit preserves pagination metadata and loads the next page', () async {
    final repository = _FakeTheftRepository()
      ..activePages = {
        1: _page([_report()], page: 1, totalCount: 2, totalPages: 2),
        2: _page([_report(id: 'report-2')], page: 2, totalCount: 2, totalPages: 2),
      };
    final cubit = TheftReportsCubit(GetActiveTheftReports(repository));
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.error, isNull);
    expect(cubit.state.reports.map((report) => report.id), ['report-1', 'report-2']);
    expect(cubit.state.page, 2);
    expect(cubit.state.pageSize, 20);
    expect(cubit.state.totalCount, 2);
    expect(cubit.state.totalPages, 2);
  });

  test('personal reports Cubit only sends recovered or closed status updates', () async {
    final repository = _FakeTheftRepository()..myPages = {1: _page([_report()], page: 1, totalCount: 1, totalPages: 1)};
    final cubit = MyTheftReportsCubit(GetMyTheftReports(repository), UpdateTheftReportStatus(repository));
    addTearDown(cubit.close);
    await cubit.load();

    expect(await cubit.updateStatus('report-1', TheftReportStatus.reported), isFalse);
    expect(repository.statusUpdates, isEmpty);
    expect(await cubit.updateStatus('report-1', TheftReportStatus.recovered), isTrue);
    expect(repository.statusUpdates, [('report-1', TheftReportStatus.recovered)]);
    expect(cubit.state.reports.single.status, TheftReportStatus.recovered);
  });

  test('personal reports Cubit preserves pagination metadata', () async {
    final repository = _FakeTheftRepository()
      ..myPages = {1: _page([_report()], page: 1, totalCount: 21, totalPages: 2)};
    final cubit = MyTheftReportsCubit(GetMyTheftReports(repository), UpdateTheftReportStatus(repository));
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.page, 1);
    expect(cubit.state.pageSize, 20);
    expect(cubit.state.totalCount, 21);
    expect(cubit.state.totalPages, 2);
  });

  test('personal reports Cubit requests and appends the next page', () async {
    final repository = _FakeTheftRepository()
      ..myPages = {
        1: _page([_report()], page: 1, totalCount: 2, totalPages: 2),
        2: _page([_report(id: 'report-2')], page: 2, totalCount: 2, totalPages: 2),
      };
    final cubit = MyTheftReportsCubit(GetMyTheftReports(repository), UpdateTheftReportStatus(repository));
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.loadMore();

    expect(repository.myReportRequests, [(1, 20), (2, 20)]);
    expect(cubit.state.reports.map((report) => report.id), ['report-1', 'report-2']);
    expect(cubit.state.page, 2);
    expect(cubit.state.pageSize, 20);
    expect(cubit.state.totalCount, 2);
    expect(cubit.state.totalPages, 2);
  });

  testWidgets('theft report card renders public motorcycle information and status', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TheftReportCard(report: _report()))));

    expect(find.text('Moto robada'), findsOneWidget);
    expect(find.textContaining('Honda CB 190R'), findsOneWidget);
    expect(find.text('Reportado'), findsOneWidget);
  });
}

Map<String, dynamic> _reportJson(String id) => {
  'id': id,
  'title': 'Moto robada',
  'description': 'Detalle',
  'theftDate': '2026-09-20T10:30:00Z',
  'status': 'Reported',
  'createdAt': '2026-09-20T11:00:00Z',
    };

TheftReport _report({String id = 'report-1', TheftReportStatus status = TheftReportStatus.reported}) => TheftReport(
  id: id,
      title: 'Moto robada',
      description: 'Detalle',
      theftDate: DateTime.utc(2026, 9, 20),
      status: status,
      createdAt: DateTime.utc(2026, 9, 20, 12),
      brand: 'Honda',
      model: 'CB 190R',
    );

PagedTheftReports _page(List<TheftReport> items, {required int page, required int totalCount, required int totalPages}) => PagedTheftReports(items: items, page: page, pageSize: 20, totalCount: totalCount, totalPages: totalPages);

class _FakeTheftRepository implements TheftRepository {
  Map<int, PagedTheftReports> activePages = const {};
  Map<int, PagedTheftReports> myPages = const {};
  final List<(int, int)> myReportRequests = [];
  final List<(String, TheftReportStatus)> statusUpdates = [];

  @override
  Future<TheftReport> createReport(CreateTheftReportInput input) async => _report();

  @override
  Future<PagedTheftReports> getActiveReports({int page = 1, int pageSize = 20}) async => activePages[page] ?? _page(const [], page: page, totalCount: 0, totalPages: 0);

  @override
  Future<PagedTheftReports> getMyReports({int page = 1, int pageSize = 20}) async {
    myReportRequests.add((page, pageSize));
    return myPages[page] ?? _page(const [], page: page, totalCount: 0, totalPages: 0);
  }

  @override
  Future<TheftReport> getReport(String id) async => _report();

  @override
  Future<TheftReport> updateStatus(String id, TheftReportStatus status) async {
    statusUpdates.add((id, status));
    return _report(status: status);
  }
}