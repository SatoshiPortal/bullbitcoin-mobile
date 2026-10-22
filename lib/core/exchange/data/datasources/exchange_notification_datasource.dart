import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:bull_logger/bull_logger.dart' show log;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Maintains one notification connection, with bounded retries while visible.
class ExchangeNotificationDatasource {
  final String _baseUrl;
  final Future<String?> Function() _getApiKey;
  final WebSocketChannel Function(Uri, Map<String, dynamic>)? _openChannel;
  final bool Function() _isForeground;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();

  _NotificationConnection? _connection;
  Timer? _retryTimer;
  int _retrySeconds = 5;
  bool _disposed = false;

  ExchangeNotificationDatasource({
    required this._baseUrl,
    required this._getApiKey,
    this._openChannel,
    bool Function()? isForeground,
  }) : _isForeground = isForeground ?? _allowConnection;

  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  bool get isConnected => _connection?.isConnected ?? false;

  static bool _allowConnection() => true;

  Future<void> connect() async {
    if (_disposed || !_isForeground() || _connection != null) return;
    _cancelRetry();
    final connection = _NotificationConnection(_openChannel);
    _connection = connection;
    try {
      final key = await _getApiKey();
      if (!identical(_connection, connection)) return;
      if (!_isForeground()) {
        disconnect();
        return;
      }
      if (key == null) {
        _release(connection);
        log.fine('WebSocket connection skipped: user not authenticated');
        return;
      }

      // The attempt listens before awaiting ready. Its identity deduplicates
      // stream errors and failed handshakes.
      await connection.open(
        Uri.parse(_buildWebSocketUrl()),
        {'X-API-Key': key},
        onMessage: (message) {
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
      if (!identical(_connection, connection)) return;
      if (!_isForeground()) {
        disconnect();
        return;
      }
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
  final WebSocketChannel Function(Uri, Map<String, dynamic>)? _openChannel;
  WebSocketChannel? _channel;
  HttpClient? _client;
  StreamSubscription<dynamic>? _subscription;
  bool isConnected = false;

  _NotificationConnection(this._openChannel);

  Future<void> open(
    Uri uri,
    Map<String, dynamic> headers, {
    required void Function(dynamic) onMessage,
    required void Function(Object, StackTrace) onError,
    required void Function() onDone,
  }) {
    final WebSocketChannel channel;
    final openChannel = _openChannel;
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
    _subscription = channel.stream.listen(
      onMessage,
      onError: onError,
      onDone: onDone,
    );
    return channel.ready;
  }

  void close() {
    final listener = _subscription;
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
