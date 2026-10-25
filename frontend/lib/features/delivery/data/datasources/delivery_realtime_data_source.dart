import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../../core/constants/environment_config.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_realtime_repository.dart';
import '../models/delivery_model.dart';

class SignalRDeliveryRealtimeDataSource implements DeliveryRealtimeRepository {
  SignalRDeliveryRealtimeDataSource(this._tokenStorage);

  final TokenStorage _tokenStorage;
  final _updatesController = StreamController<Delivery>.broadcast();
  final _connectionStatesController = StreamController<DeliveryRealtimeConnectionState>.broadcast();
  final _joinedTransactions = <String>{};
  HubConnection? _connection;
  Future<void>? _startFuture;
  int _generation = 0;
  bool _stopping = false;

  @override
  Stream<Delivery> get updates => _updatesController.stream;

  @override
  Stream<DeliveryRealtimeConnectionState> get connectionStates => _connectionStatesController.stream;

  @override
  Future<void> start() {
    final pending = _startFuture;
    if (pending != null) return pending;
    final existing = _connection;
    if (existing != null && (existing.state == HubConnectionState.Connected || existing.state == HubConnectionState.Connecting || existing.state == HubConnectionState.Reconnecting)) {
      return Future.value();
    }

    final generation = ++_generation;
    _stopping = false;
    final future = _startConnection(generation);
    _startFuture = future;
    return future.whenComplete(() {
      if (identical(_startFuture, future)) _startFuture = null;
    });
  }

  Future<void> _startConnection(int generation) async {
    final connection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => (await _tokenStorage.accessToken) ?? '',
            transport: HttpTransportType.WebSockets,
            skipNegotiation: true,
            logMessageContent: false,
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 10000, 30000])
        .build();
    _connection = connection;
    _registerHandlers(connection, generation);
    _emitConnectionState(DeliveryRealtimeConnectionState.connecting);
    try {
      await connection.start();
      if (_isCurrent(connection, generation)) _emitConnectionState(DeliveryRealtimeConnectionState.connected);
    } catch (_) {
      if (_isCurrent(connection, generation)) {
        _connection = null;
        _emitConnectionState(DeliveryRealtimeConnectionState.failed);
      }
      rethrow;
    }
  }

  void _registerHandlers(HubConnection connection, int generation) {
    connection.on('DeliveryUpdated', (arguments) {
      if (!_isCurrent(connection, generation) || arguments == null || arguments.isEmpty || arguments.first is! Map) return;
      try {
        _updatesController.add(DeliveryModel.fromJson(Map<String, dynamic>.from(arguments.first as Map)));
      } catch (_) {
        // Ignore malformed events so the shared stream remains usable.
      }
    });
    connection.onreconnecting(({error}) {
      if (_isCurrent(connection, generation)) _emitConnectionState(DeliveryRealtimeConnectionState.reconnecting);
    });
    connection.onreconnected(({connectionId}) {
      if (!_isCurrent(connection, generation)) return;
      _emitConnectionState(DeliveryRealtimeConnectionState.connected);
      unawaited(_restoreSubscriptions(connection));
    });
    connection.onclose(({error}) {
      if (_isCurrent(connection, generation) && !_stopping) _emitConnectionState(DeliveryRealtimeConnectionState.disconnected);
    });
  }

  @override
  Future<void> joinDelivery(String transactionId) async {
    _joinedTransactions.add(transactionId);
    final connection = _connection;
    if (connection?.state == HubConnectionState.Connected) {
      await connection!.invoke('JoinDelivery', args: [transactionId]);
    }
  }

  @override
  Future<void> leaveDelivery(String transactionId) async {
    _joinedTransactions.remove(transactionId);
    final connection = _connection;
    if (connection?.state == HubConnectionState.Connected) {
      await connection!.invoke('LeaveDelivery', args: [transactionId]);
    }
  }

  Future<void> _restoreSubscriptions(HubConnection connection) async {
    for (final transactionId in _joinedTransactions) {
      try {
        await connection.invoke('JoinDelivery', args: [transactionId]);
      } catch (_) {
        // Automatic reconnect can finish before the server is ready for invocations.
      }
    }
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    _generation++;
    final connection = _connection;
    _connection = null;
    _startFuture = null;
    _joinedTransactions.clear();
    if (connection != null) await connection.stop();
    _emitConnectionState(DeliveryRealtimeConnectionState.disconnected);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _updatesController.close();
    await _connectionStatesController.close();
  }

  bool _isCurrent(HubConnection connection, int generation) => identical(_connection, connection) && _generation == generation;

  void _emitConnectionState(DeliveryRealtimeConnectionState state) {
    if (!_connectionStatesController.isClosed) _connectionStatesController.add(state);
  }

  String get _hubUrl {
    final apiUri = Uri.parse(EnvironmentConfig.apiBaseUrl);
    final apiPath = apiUri.path;
    final rootPath = apiPath.endsWith('/api') ? apiPath.substring(0, apiPath.length - 4) : apiPath;
    return apiUri.replace(path: '$rootPath/hubs/delivery').toString();
  }
}