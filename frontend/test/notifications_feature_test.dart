import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohub/core/error/app_failure.dart';
import 'package:motohub/features/notifications/data/models/notification_models.dart';
import 'package:motohub/features/notifications/data/datasources/notifications_data_source.dart';
import 'package:motohub/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:motohub/features/notifications/domain/entities/notification.dart';
import 'package:motohub/features/notifications/domain/entities/paged_notifications.dart';
import 'package:motohub/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:motohub/features/notifications/domain/usecases/get_notifications.dart';
import 'package:motohub/features/notifications/domain/usecases/get_unread_notification_count.dart';
import 'package:motohub/features/notifications/domain/usecases/mark_all_notifications_as_read.dart';
import 'package:motohub/features/notifications/domain/usecases/mark_notification_as_read.dart';
import 'package:motohub/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:motohub/features/notifications/presentation/widgets/notification_badge.dart';

void main() {
  test('parses numeric and unknown notification types safely', () {
    final theft = NotificationModel.fromJson(_json(type: 5));
    final unknown = NotificationModel.fromJson(_json(type: 99));

    expect(theft.type, NotificationType.theft);
    expect(unknown.type, NotificationType.unknown);
  });

  test('parses valid target and ignores invalid targets', () {
    final valid = NotificationModel.fromJson(_json(target: {
      'resourceType': 'Product',
      'resourceId': '11111111-1111-4111-8111-111111111111',
    }));
    final invalid = NotificationModel.fromJson(_json(target: {
      'resourceType': 'Message',
      'resourceId': 'not-a-guid',
    }));

    expect(valid.target?.resourceType, NotificationResourceType.product);
    expect(valid.target?.resourceId, '11111111-1111-4111-8111-111111111111');
    expect(invalid.target, isNull);
  });

  test('requires a structurally valid paged response', () {
    final page = PagedNotificationsModel.fromJson({
      'items': [_json(type: 0, target: null)],
      'page': 1,
      'pageSize': 20,
      'totalCount': 1,
      'totalPages': 1,
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.readAt, isNull);
    expect(() => PagedNotificationsModel.fromJson({'items': 'invalid'}), throwsA(isA<Exception>()));
  });

  test('repository maps the real data source contract and 204 actions', () async {
    final adapter = _NotificationsAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final repository = NotificationsRepositoryImpl(NotificationsDataSource(dio));

    final page = await repository.getNotifications(page: 1, unreadOnly: true, type: NotificationType.theft);
    await repository.markAsRead('notification-1');
    await repository.markAllAsRead();

    expect(page.items.single.type, NotificationType.theft);
    expect(await repository.getUnreadCount(), 1);
    expect(adapter.readCalls, 1);
    expect(adapter.readAllCalls, 1);
  });

  test('cubit loads, updates unread count and does not duplicate mark-read', () async {
    final repository = _FakeNotificationsRepository(
      pages: [PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1)],
      unreadCount: 1,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.items.single.isRead, isFalse);
    expect(cubit.state.unreadCount, 1);

    expect(await cubit.markAsRead(_notification.id), isTrue);
    expect(await cubit.markAsRead(_notification.id), isTrue);

    expect(repository.markReadCalls, 1);
    expect(cubit.state.items.single.isRead, isTrue);
    expect(cubit.state.unreadCount, 0);
  });

  test('cubit mark-all updates local state and clear invalidates state', () async {
    final repository = _FakeNotificationsRepository(
      pages: [PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1)],
      unreadCount: 1,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.markAllAsRead();
    expect(repository.markAllCalls, 1);
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.items.single.isRead, isTrue);

    cubit.clear();
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.page, 0);
  });

  test('cubit ignores a response that completes after clear', () async {
    final pending = Completer<PagedNotifications>();
    final repository = _FakeNotificationsRepository(pendingPage: pending.future);
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    final load = cubit.load();
    cubit.clear();
    pending.complete(PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1));
    await load;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.page, 0);
  });

  test('cubit ignores stale mark-read response after clear', () async {
    final pending = Completer<void>();
    final repository = _FakeNotificationsRepository(
      pages: [PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1)],
      unreadCount: 1,
      pendingMarkRead: pending.future,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    final markRead = cubit.markAsRead(_notification.id);
    cubit.clear();
    pending.complete();

    expect(await markRead, isFalse);
    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.actionFailure, isNull);
  });

  test('cubit ignores stale mark-all response after clear', () async {
    final pending = Completer<void>();
    final repository = _FakeNotificationsRepository(
      pages: [PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1)],
      unreadCount: 1,
      pendingMarkAll: pending.future,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    final markAll = cubit.markAllAsRead();
    cubit.clear();
    pending.complete();
    await markAll;

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
    expect(cubit.state.actionFailure, isNull);
  });

  test('cubit keeps an item unread when mark-read fails', () async {
    final repository = _FakeNotificationsRepository(
      pages: [PagedNotifications(items: [_notification], page: 1, pageSize: 20, totalCount: 1, totalPages: 1)],
      unreadCount: 1,
      failMarkRead: true,
    );
    final cubit = _createCubit(repository);
    addTearDown(cubit.close);

    await cubit.load();
    expect(await cubit.markAsRead(_notification.id), isFalse);
    expect(cubit.state.items.single.isRead, isFalse);
    expect(cubit.state.unreadCount, 1);
    expect(cubit.state.actionFailure, isNotNull);
  });

  testWidgets('badge is hidden at zero and caps large values', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Stack(children: [
      Icon(Icons.notifications),
      NotificationBadge(count: 0),
      NotificationBadge(count: 120),
    ])));

    expect(find.text('99+'), findsOneWidget);
  });
}

Map<String, dynamic> _json({Object? type = 0, Object? target}) => {
      'id': '11111111-1111-4111-8111-111111111111',
      'type': type,
      'title': 'Aviso',
      'body': 'Contenido',
      'isRead': false,
      'readAt': null,
      'createdAt': '2026-09-23T12:00:00Z',
      'target': target,
    };

final _notification = AppNotification(
  id: 'notification-1',
  type: NotificationType.system,
  title: 'Aviso',
  body: 'Contenido',
  isRead: false,
  readAt: null,
  createdAt: DateTime.utc(2026, 9, 23),
  target: null,
);

NotificationsCubit _createCubit(_FakeNotificationsRepository repository) => NotificationsCubit(
      GetNotifications(repository),
      GetUnreadNotificationCount(repository),
      MarkNotificationAsRead(repository),
      MarkAllNotificationsAsRead(repository),
    );

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository({this.pages = const [], this.unreadCount = 0, this.pendingPage, this.pendingMarkRead, this.pendingMarkAll, this.failMarkRead = false});

  final List<PagedNotifications> pages;
  final Future<PagedNotifications>? pendingPage;
  final Future<void>? pendingMarkRead;
  final Future<void>? pendingMarkAll;
  final bool failMarkRead;
  int unreadCount;
  int markReadCalls = 0;
  int markAllCalls = 0;

  @override
  Future<PagedNotifications> getNotifications({required int page, int pageSize = 20, bool unreadOnly = false, NotificationType? type}) async => pendingPage ?? pages[page - 1];

  @override
  Future<int> getUnreadCount() async => unreadCount;

  @override
  Future<void> markAsRead(String id) async {
    if (failMarkRead) throw const NotFoundFailure('No existe.');
    final pending = pendingMarkRead;
    if (pending != null) await pending;
    markReadCalls++;
    unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
  }

  @override
  Future<void> markAllAsRead() async {
    final pending = pendingMarkAll;
    if (pending != null) await pending;
    markAllCalls++;
    unreadCount = 0;
  }
}

class _NotificationsAdapter implements HttpClientAdapter {
  int readCalls = 0;
  int readAllCalls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path == '/api/notifications') {
      expect(options.queryParameters['page'], 1);
      expect(options.queryParameters['unreadOnly'], true);
      expect(options.queryParameters['type'], 5);
      return _jsonResponse({
        'items': [_json(type: 5)],
        'page': 1,
        'pageSize': 20,
        'totalCount': 1,
        'totalPages': 1,
      });
    }
    if (options.path == '/api/notifications/unread-count') return _jsonResponse({'count': 1});
    if (options.path == '/api/notifications/notification-1/read') {
      readCalls++;
      return ResponseBody(const Stream<Uint8List>.empty(), 204);
    }
    if (options.path == '/api/notifications/read-all') {
      readAllCalls++;
      return ResponseBody(const Stream<Uint8List>.empty(), 204);
    }
    return ResponseBody(const Stream<Uint8List>.empty(), 404);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> data) => ResponseBody(
      Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(jsonEncode(data)))),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
