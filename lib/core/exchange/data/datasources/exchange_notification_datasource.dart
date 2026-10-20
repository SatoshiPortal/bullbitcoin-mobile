import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Maintains one notification connection, with bounded retries while visible.
class ExchangeNotificationDatasource {
  final String _baseUrl;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;
  final WebSocketChannel Function(Uri, Map<String, dynamic>)? _openChannel;
  final bool Function() _isForeground;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();

  _NotificationConnection? _connection;
  Timer? _retryTimer;
  int _retrySeconds = 5;
  bool _disposed = false;

  ExchangeNotificationDatasource({
    required this._baseUrl,
    required this._apiKeyDatasource,
    required this._isTestnet,
    this._openChannel,
    bool Function()? isForeground,
  }) : _isForeground = isForeground ?? _allowConnection;

  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  bool get isConnected => _connection?.isConnected ?? false;

  static bool _allowConnection() => true;

  Future<void> connect() async {
    if (_disposed || !_isForeground() || _connection != null) return;
    _cancelRetry();
    final connection = _NotificationConnection();
    _connection = connection;
    try {
      final key = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (!_canContinue(connection)) return;
      if (key == null || !key.isActive) {
        _release(connection);
        log.fine('WebSocket connection skipped: user not authenticated');
        return;
      }

      final channel = connection.open(Uri.parse(_buildWebSocketUrl()), {
        'X-API-Key': key.key,
      }, _openChannel);
      // Handshake failures also arrive on the stream. Listen before ready,
      // and let connection identity deduplicate the two failure paths.
      connection.subscription = channel.stream.listen(
        (message) {
          if (identical(_connection, connection) && _isForeground()) {
            _handleMessage(message);
          }
        },
        onError: (Object error, StackTrace trace) {
          if (!identical(_connection, connection)) return;
          if (error is Error) {
            _release(connection);
            Error.throwWithStackTrace(error, trace);
          }
          _connectionLost(connection, error);
        },
        onDone: () => _connectionLost(connection),
      );
      await channel.ready;
      if (!_canContinue(connection)) return;
      connection.isConnected = true;
      _retrySeconds = 5;
      log.fine('WebSocket connected successfully');
    } on Exception catch (error) {
      _connectionLost(connection, error);
    } finally {
      // A programmer error still propagates, but must release its attempt.
      if (!connection.isConnected) _release(connection);
    }
  }

  void disconnect() {
    _cancelRetry();
    _retrySeconds = 5;
    final connection = _connection;
    if (connection != null) _release(connection);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    unawaited(_messages.close());
  }

  bool _canContinue(_NotificationConnection connection) {
    if (!identical(_connection, connection)) return false;
    if (_isForeground()) return true;
    disconnect();
    return false;
  }

  void _release(_NotificationConnection connection) {
    if (!identical(_connection, connection)) return;
    // Invalidate before closing: callbacks from this socket are now stale.
    _connection = null;
    connection.close();
  }

  void _connectionLost(_NotificationConnection connection, [Object? error]) {
    if (!identical(_connection, connection)) return;
    _release(connection);
    if (error != null) {
      if (error.toString().contains('not upgraded to websocket')) {
        log.warning('WebSocket endpoint unavailable; auto-reconnect disabled');
        return;
      }
      log.warning(
        'WebSocket connection failed (foreground=${_isForeground()})',
        error: error,
      );
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || !_isForeground() || _retryTimer != null) return;
    final delay = Duration(seconds: _retrySeconds);
    _retrySeconds = (_retrySeconds * 2).clamp(5, 60);
    log.fine('WebSocket reconnect scheduled in ${delay.inSeconds}s');
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(connect());
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _handleMessage(dynamic message) {
    try {
      final parsed = message is String
          ? jsonDecode(message) as Map<String, dynamic>
          : message as Map<String, dynamic>;
      // The payload carries account data; only its type belongs in logs.
      log.fine('WebSocket message received: type=${parsed['type']}');
      _messages.add(parsed);
    } catch (error) {
      // FormatException embeds the malformed frame in its message.
      log.warning('Error parsing WebSocket message: ${error.runtimeType}');
    }
  }

  String _buildWebSocketUrl() {
    // Clean the base URL - remove trailing slashes and whitespace
    var baseUrl = _baseUrl.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Convert HTTP(S) to WS(S) - case insensitive
    String wsUrl;
    if (baseUrl.toLowerCase().startsWith('https://')) {
      wsUrl = 'wss://${baseUrl.substring(8)}';
    } else if (baseUrl.toLowerCase().startsWith('http://')) {
      wsUrl = 'ws://${baseUrl.substring(7)}';
    } else {
      // Assume wss if no protocol specified
      wsUrl = baseUrl.startsWith('wss://') || baseUrl.startsWith('ws://')
          ? baseUrl
          : 'wss://$baseUrl';
    }

    // Use /ak/ prefix for API key authenticated endpoint
    return '$wsUrl/ak/api-commcenter';
  }
}

/// Resources belong to one attempt, from handshake through disconnection.
/// Replacing the attempt cannot accidentally close a newer socket.
class _NotificationConnection {
  WebSocketChannel? _channel;
  HttpClient? _client;
  StreamSubscription<dynamic>? subscription;
  bool isConnected = false;

  WebSocketChannel open(
    Uri uri,
    Map<String, dynamic> headers,
    WebSocketChannel Function(Uri, Map<String, dynamic>)? openChannel,
  ) {
    final WebSocketChannel channel;
    if (openChannel != null) {
      channel = openChannel(uri, headers);
    } else {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      _client = client;
      channel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        pingInterval: const Duration(seconds: 30),
        connectTimeout: const Duration(seconds: 15),
        customClient: client,
      );
    }
    _channel = channel;
    return channel;
  }

  void close() {
    final listener = subscription;
    if (listener != null) unawaited(listener.cancel());
    // Abort the native request too: a Future timeout alone leaves it alive.
    _client?.close(force: true);
    final channel = _channel;
    if (channel != null) {
      unawaited(
        channel.sink.close().catchError((Object error) {
          log.warning('WebSocket close failed: ${error.runtimeType}');
        }, test: (Object error) => error is Exception),
      );
    }
  }
}
