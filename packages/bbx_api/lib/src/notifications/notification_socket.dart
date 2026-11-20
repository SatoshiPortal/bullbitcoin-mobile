import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens the socket to [uri] sending [headers] in the handshake and pinging
/// every [pingInterval].
typedef BbxWebSocketConnector = WebSocketChannel Function(
  Uri uri, {
  required Map<String, Object> headers,
  required Duration pingInterval,
});

/// Severity of a [BbxNotificationSocket] diagnostic.
enum BbxNotificationLogLevel { fine, info, warning }

/// Receives the socket's diagnostics. [message] is a fixed text and [error]
/// is at most the failure's runtime type; neither carries frames or keys.
typedef BbxNotificationLog = void Function(
  BbxNotificationLogLevel level,
  String message, {
  Type? error,
});

WebSocketChannel _ioConnector(
  Uri uri, {
  required Map<String, Object> headers,
  required Duration pingInterval,
}) => IOWebSocketChannel.connect(
  uri,
  headers: headers,
  pingInterval: pingInterval,
);

void _noLog(BbxNotificationLogLevel level, String message, {Type? error}) {}

/// The exchange notification socket, `/ak/api-commcenter`, authenticated
/// with the `X-API-Key` header.
///
/// [connector] opens the socket, by default with `dart:io`.
/// [readApiKey] is called before every handshake. A `null` key means the
/// user is signed out: the socket stays closed until the next [connect]. An
/// [Exception] thrown by [readApiKey] or by the connection is a failure:
/// the socket retries 5 seconds later until [disconnect] or [dispose]. An
/// [Error] disconnects and propagates.
///
/// [messages] emits each frame that decodes to a JSON object; other frames
/// are dropped.
class BbxNotificationSocket {
  // A missed pong closes the socket, so a connection the OS dropped silently
  // reaches _handleDisconnect and auto-reconnects.
  static const pingInterval = Duration(seconds: 30);
  static const retryDelay = Duration(seconds: 5);

  final String _baseUrl;
  final Future<String?> Function() _readApiKey;
  final BbxWebSocketConnector _connector;
  final BbxNotificationLog _log;

  WebSocketChannel? _channel;
  Object? _attempt;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _hasConnectionFailure = false;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;
  bool _isConnecting = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  BbxNotificationSocket({
    required this._baseUrl,
    required this._readApiKey,
    BbxWebSocketConnector? connector,
    this._log = _noLog,
  }) : _connector = connector ?? _ioConnector;

  /// The socket URL for the API at [baseUrl]: `http(s)` becomes `ws(s)`,
  /// a missing scheme becomes `wss`, trailing slashes are dropped.
  static String webSocketUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    String wsUrl;
    if (url.toLowerCase().startsWith('https://')) {
      wsUrl = 'wss://${url.substring(8)}';
    } else if (url.toLowerCase().startsWith('http://')) {
      wsUrl = 'ws://${url.substring(7)}';
    } else {
      wsUrl = url.startsWith('wss://') || url.startsWith('ws://')
          ? url
          : 'wss://$url';
    }

    return '$wsUrl/ak/api-commcenter';
  }

  Uri get uri => Uri.parse(webSocketUrl(_baseUrl));

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_disposed || _isConnected || _isConnecting) return;
    _retryTimer?.cancel();
    final attempt = Object();
    _attempt = attempt;
    _isConnecting = true;
    _isManuallyDisconnected = false;

    try {
      final apiKey = await _readApiKey();
      if (!identical(_attempt, attempt)) return;
      if (apiKey == null) {
        _attempt = null;
        _isConnecting = false;
        _isManuallyDisconnected = true;
        _hasConnectionFailure = false;
        _log(
          BbxNotificationLogLevel.fine,
          'WebSocket skipped: user not authenticated',
        );
        return;
      }

      final channel = _connector(
        uri,
        headers: {'X-API-Key': apiKey},
        pingInterval: pingInterval,
      );
      _channel = channel;
      _subscription = channel.stream.listen(
        (message) {
          if (identical(_attempt, attempt)) _handleMessage(message);
        },
        onError: (Object error) {
          if (identical(_attempt, attempt)) _handleError(error);
        },
        onDone: () {
          if (identical(_attempt, attempt)) _handleDisconnect();
        },
      );
      await channel.ready;
      if (!identical(_attempt, attempt)) return;
      _isConnected = true;
      _isConnecting = false;
      _hasConnectionFailure = false;
      _log(BbxNotificationLogLevel.fine, 'WebSocket connected successfully');
    } catch (error) {
      if (error is Error) {
        if (identical(_attempt, attempt)) disconnect();
        rethrow;
      }
      if (!identical(_attempt, attempt)) return;
      _isConnecting = false;
      if (error.toString().contains('not upgraded to websocket')) {
        _isManuallyDisconnected = true;
      }
      _recordConnectionFailure(error);
      _handleDisconnect();
    }
  }

  void _handleMessage(Object? message) {
    final Object? decoded;
    try {
      decoded = message is String ? jsonDecode(message) : message;
    } on FormatException {
      _log(
        BbxNotificationLogLevel.warning,
        'WebSocket message rejected: invalid JSON',
      );
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      _log(
        BbxNotificationLogLevel.warning,
        'WebSocket message rejected: invalid shape',
      );
      return;
    }
    // Even the discriminator is untrusted and may contain account data.
    _log(BbxNotificationLogLevel.info, 'WebSocket message received');
    _messageController.add(decoded);
  }

  void _handleDisconnect() {
    _attempt = null;
    _isConnected = false;
    _isConnecting = false;
    _closeChannel();
    if (_isManuallyDisconnected || _disposed || _retryTimer?.isActive == true) {
      return;
    }
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      if (!_isManuallyDisconnected && !_disposed) unawaited(connect());
    });
  }

  void _closeChannel() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(
        channel.sink.close().catchError((Object error) {
          _log(
            BbxNotificationLogLevel.info,
            'WebSocket close cleanup failed',
            error: error.runtimeType,
          );
        }, test: (Object error) => error is Exception),
      );
    }
  }

  void _recordConnectionFailure(Object error) {
    if (_hasConnectionFailure) {
      _log(
        BbxNotificationLogLevel.info,
        'WebSocket retry failed',
        error: error.runtimeType,
      );
      return;
    }
    _hasConnectionFailure = true;
    _log(
      BbxNotificationLogLevel.warning,
      'WebSocket unavailable',
      error: error.runtimeType,
    );
  }

  void _handleError(Object error) {
    if (error is Error) {
      disconnect();
      throw error;
    }
    _recordConnectionFailure(error);
    _handleDisconnect();
  }

  void disconnect() {
    _hasConnectionFailure = false;
    _isManuallyDisconnected = true;
    _isConnecting = false;
    _attempt = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeChannel();
    _isConnected = false;
    _log(BbxNotificationLogLevel.info, 'WebSocket manually disconnected');
  }

  Future<void> reconnect() async {
    disconnect();
    await connect();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    unawaited(_messageController.close());
  }
}
