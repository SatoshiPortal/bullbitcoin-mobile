import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ExchangeNotificationDatasource {
  // A missed pong closes the socket, so a connection the OS dropped silently
  // reaches _handleDisconnect and auto-reconnects.
  static const _pingInterval = Duration(seconds: 30);

  final String _baseUrl;
  final ReadExchangeApiKey _readApiKey;

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
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;

  ExchangeNotificationDatasource({
    required this._baseUrl,
    required this._readApiKey,
  });

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

  Future<void> connect() async {
    if (_disposed || _isConnected || _isConnecting) return;
    _retryTimer?.cancel();
    final attempt = Object();
    _attempt = attempt;
    _isConnecting = true;
    _isManuallyDisconnected = false;

    try {
      final credential = await _readApiKey();
      if (!identical(_attempt, attempt)) return;
      final String? apiKey;
      switch (credential) {
        case Ok(:final value):
          apiKey = value;
        case Err(:final failure):
          throw ExchangeAuthenticationException(failure);
      }
      if (apiKey == null) {
        _attempt = null;
        _isConnecting = false;
        _isManuallyDisconnected = true;
        _hasConnectionFailure = false;
        log.fine('WebSocket skipped: user not authenticated');
        return;
      }

      final channel = IOWebSocketChannel.connect(
        Uri.parse(_buildWebSocketUrl()),
        headers: {'X-API-Key': apiKey},
        pingInterval: _pingInterval,
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
      log.fine('WebSocket connected successfully');
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
      log.warning('WebSocket message rejected: invalid JSON');
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      log.warning('WebSocket message rejected: invalid shape');
      return;
    }
    // Even the discriminator is untrusted and may contain account data.
    log.info('WebSocket message received');
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
    _retryTimer = Timer(const Duration(seconds: 5), () {
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
          log.info('WebSocket close cleanup failed', error: error.runtimeType);
        }, test: (Object error) => error is Exception),
      );
    }
  }

  void _recordConnectionFailure(Object error) {
    if (_hasConnectionFailure) {
      log.info('WebSocket retry failed', error: error.runtimeType);
      return;
    }
    _hasConnectionFailure = true;
    log.warning('WebSocket unavailable', error: error.runtimeType);
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
    log.info('WebSocket manually disconnected');
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
