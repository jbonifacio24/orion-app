import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../../../core/constants/environment_config.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_realtime_repository.dart';
import '../models/chat_models.dart';

class SignalRChatRealtimeDataSource implements ChatRealtimeRepository {
  SignalRChatRealtimeDataSource(this._tokenStorage);

  final TokenStorage _tokenStorage;
  final _messagesController = StreamController<ChatMessage>.broadcast();
  final _connectionStatesController = StreamController<ChatRealtimeConnectionState>.broadcast();

  HubConnection? _connection;
  Future<void>? _startFuture;
  int _sessionGeneration = 0;
  bool _stopping = false;

  @override
  Stream<ChatMessage> get messages => _messagesController.stream;

  @override
  Stream<ChatRealtimeConnectionState> get connectionStates => _connectionStatesController.stream;

  @override
  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    final connection = _connection;
    if (connection != null &&
        (connection.state == HubConnectionState.Connected ||
            connection.state == HubConnectionState.Connecting ||
            connection.state == HubConnectionState.Reconnecting)) {
      return Future.value();
    }

    final generation = ++_sessionGeneration;
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
    _emitState(ChatRealtimeConnectionState.connecting);

    try {
      await connection.start();
      if (!_isCurrent(connection, generation)) return;
      _emitState(ChatRealtimeConnectionState.connected);
    } catch (_) {
      if (_isCurrent(connection, generation)) {
        _connection = null;
        _emitState(ChatRealtimeConnectionState.failed);
      }
      rethrow;
    }
  }

  void _registerHandlers(HubConnection connection, int generation) {
    connection.on('MessageReceived', (arguments) {
      if (!_isCurrent(connection, generation) || arguments == null || arguments.isEmpty) return;
      final payload = arguments.first;
      if (payload is! Map) return;
      try {
        final json = Map<String, dynamic>.from(payload);
        _messagesController.add(ChatMessageModel.fromJson(json));
      } catch (_) {
        // A malformed event must not terminate the shared realtime stream.
      }
    });
    connection.onreconnecting(({error}) {
      if (_isCurrent(connection, generation)) _emitState(ChatRealtimeConnectionState.reconnecting);
    });
    connection.onreconnected(({connectionId}) {
      if (_isCurrent(connection, generation)) _emitState(ChatRealtimeConnectionState.connected);
    });
    connection.onclose(({error}) {
      if (_isCurrent(connection, generation) && !_stopping) {
        _emitState(ChatRealtimeConnectionState.disconnected);
      }
    });
  }

  @override
  Future<void> joinConversation(String conversationId) async {
    final connection = _connection;
    if (connection?.state != HubConnectionState.Connected) return;
    await connection!.invoke('JoinConversation', args: [conversationId]);
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    final connection = _connection;
    if (connection?.state != HubConnectionState.Connected) return;
    await connection!.invoke('LeaveConversation', args: [conversationId]);
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    _sessionGeneration++;
    final connection = _connection;
    _connection = null;
    _startFuture = null;
    if (connection != null) await connection.stop();
    _emitState(ChatRealtimeConnectionState.disconnected);
  }

  bool _isCurrent(HubConnection connection, int generation) => identical(_connection, connection) && _sessionGeneration == generation;

  void _emitState(ChatRealtimeConnectionState state) {
    if (!_connectionStatesController.isClosed) _connectionStatesController.add(state);
  }

  String get _hubUrl {
    final apiUri = Uri.parse(EnvironmentConfig.apiBaseUrl);
    final apiPath = apiUri.path;
    final rootPath = apiPath.endsWith('/api') ? apiPath.substring(0, apiPath.length - 4) : apiPath;
    return apiUri.replace(path: '$rootPath/hubs/chat').toString();
  }
}
