import 'dart:async';
import 'dart:convert';

import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/notifications/bbx_notification.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Opens the socket to [uri] sending [headers] in the handshake and pinging
/// every [pingInterval].
typedef BbxWebSocketConnector = WebSocketChannel Function(
  Uri uri, {
  required Map<String, Object> headers,
  required Duration pingInterval,
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

@internal
BbxNotificationSocket openBbxNotificationSocket({
  required String baseUrl,
  required Future<Result<String?, BbxFailure>> Function() readApiKey,
  BbxNotificationLog log = _noLog,
}) => BbxNotificationSocket._(baseUrl, readApiKey, _ioConnector, log);

BbxNotificationSocket bbxNotificationSocketForTesting({
  required String baseUrl,
  required Future<Result<String?, BbxFailure>> Function() readApiKey,
  BbxWebSocketConnector? connector,
  BbxNotificationLog log = _noLog,
}) => BbxNotificationSocket._(
  baseUrl,
  readApiKey,
  connector ?? _ioConnector,
  log,
);

/// The exchange notification socket, `/ak/api-commcenter`, authenticated
/// with the `X-API-Key` header. Instances come from `Bbx.open`; tests use
/// `package:bbx_api/bbx_api_testing.dart`.
///
/// The credential is read before every handshake. `Ok(null)` means the user is
/// signed out: the socket stays closed, emits nothing and never retries until
/// the next [connect]. A credential or connection failure is emitted on
/// [events] and returned by [connect], and the socket retries 5 seconds later
/// until [disconnect] or [dispose]. An [Error] disconnects and propagates.
///
/// [events] emits a decoded notification for each valid frame and a
/// [BbxResponseFormatFailure] for each malformed frame. Raw frames remain
/// private to the package.
class BbxNotificationSocket {
  // A missed pong closes the socket, so a connection the OS dropped silently
  // reaches _handleDisconnect and auto-reconnects.
  static const pingInterval = Duration(seconds: 30);
  static const retryDelay = Duration(seconds: 5);

  final String _baseUrl;
  final Future<Result<String?, BbxFailure>> Function() _readApiKey;
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

  final _eventController =
      StreamController<Result<BbxNotification, BbxFailure>>.broadcast();

  BbxNotificationSocket._(
    this._baseUrl,
    this._readApiKey,
    this._connector,
    this._log,
  );

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

  Stream<Result<BbxNotification, BbxFailure>> get events =>
      _eventController.stream;

  bool get isConnected => _isConnected;

  Future<Result<void, BbxFailure>> connect() async {
    if (_disposed || _isConnected || _isConnecting) return const Ok(null);
    _retryTimer?.cancel();
    final attempt = Object();
    _attempt = attempt;
    _isConnecting = true;
    _isManuallyDisconnected = false;

    try {
      final credential = await _readApiKey();
      if (!identical(_attempt, attempt)) return const Ok(null);
      final String? apiKey;
      switch (credential) {
        case Ok(:final value):
          apiKey = value;
        case Err(:final failure):
          return _connectionFailure(failure);
      }
      if (apiKey == null) {
        // Signed out: not a failure, so nothing is emitted and no retry is
        // scheduled. The next connect reads the credential again.
        _attempt = null;
        _isConnecting = false;
        _isManuallyDisconnected = true;
        _hasConnectionFailure = false;
        _log(
          BbxNotificationLogLevel.fine,
          'WebSocket skipped: user not authenticated',
        );
        return const Ok(null);
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
      if (!identical(_attempt, attempt)) {
        return const Ok(null);
      }
      _isConnected = true;
      _isConnecting = false;
      _hasConnectionFailure = false;
      _log(BbxNotificationLogLevel.fine, 'WebSocket connected successfully');
      return const Ok(null);
    } catch (error) {
      if (error is Error) {
        if (identical(_attempt, attempt)) disconnect();
        rethrow;
      }
      if (!identical(_attempt, attempt)) {
        return const Ok(null);
      }
      if (error.toString().contains('not upgraded to websocket')) {
        _isManuallyDisconnected = true;
      }
      return _connectionFailure(const BbxConnectionFailure());
    }
  }

  Result<void, BbxFailure> _connectionFailure(BbxFailure failure) {
    _isConnecting = false;
    _recordConnectionFailure(failure);
    _eventController.add(Err(failure));
    _handleDisconnect();
    return Err(failure);
  }

  void _handleMessage(Object? message) {
    try {
      final decoded = message is String ? jsonDecode(message) : message;
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      final notification = _decodeNotification(decoded);
      // Even the discriminator is untrusted and may contain account data.
      _log(BbxNotificationLogLevel.info, 'WebSocket message received');
      _eventController.add(Ok(notification));
    } on FormatException {
      _log(
        BbxNotificationLogLevel.warning,
        'WebSocket message rejected: invalid JSON',
      );
      _eventController.add(
        const Err(BbxResponseFormatFailure('notification frame')),
      );
    }
  }

  static BbxNotification _decodeNotification(Map<String, dynamic> json) {
    final type = json['type'];
    if (type != null && type is! String) {
      throw const FormatException('Expected a nullable string: type');
    }
    final orderId = _optionalString(json, 'orderId');
    final event = _optionalString(json, 'event');
    return BbxNotification(
      kind: switch (type) {
        'balance' => BbxNotificationKind.balance,
        'group' => BbxNotificationKind.group,
        'kyc' => BbxNotificationKind.kyc,
        'userPreferences' => BbxNotificationKind.userPreferences,
        'message' => BbxNotificationKind.message,
        'order' => BbxNotificationKind.order,
        'limitOrder' => BbxNotificationKind.limitOrder,
        'user' => BbxNotificationKind.user,
        'recipient' => BbxNotificationKind.recipient,
        _ => BbxNotificationKind.unknown,
      },
      orderId: orderId,
      event: event,
    );
  }

  static String? _optionalString(Map<String, dynamic> json, String field) {
    return switch (json[field]) {
      null => null,
      String value => value,
      _ => throw FormatException('Expected a nullable string: $field'),
    };
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

  void _recordConnectionFailure(BbxFailure failure) {
    if (_hasConnectionFailure) {
      _log(
        BbxNotificationLogLevel.info,
        'WebSocket retry failed',
        error: failure.runtimeType,
      );
      return;
    }
    _hasConnectionFailure = true;
    _log(
      BbxNotificationLogLevel.warning,
      'WebSocket unavailable',
      error: failure.runtimeType,
    );
  }

  void _handleError(Object error) {
    if (error is Error) {
      disconnect();
      throw error;
    }
    _connectionFailure(const BbxConnectionFailure());
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

  Future<Result<void, BbxFailure>> reconnect() async {
    disconnect();
    return connect();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    unawaited(_eventController.close());
  }
}
