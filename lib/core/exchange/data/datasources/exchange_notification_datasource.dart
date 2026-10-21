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
      log.warning('WebSocket connection failed: ${error.runtimeType}');
      _handleDisconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final parsed = message is String
          ? jsonDecode(message) as Map<String, dynamic>
          : message as Map<String, dynamic>;
      // Type only: the payload carries account data (group/kyc/balance
      // notifications) and the on-device log can be exported.
      log.fine('WebSocket message received: type=${parsed['type']}');
      _messageController.add(parsed);
    } catch (e) {
      // Type only: FormatException.toString() embeds the malformed frame,
      // which can carry account data.
      log.warning('Error parsing WebSocket message: ${e.runtimeType}');
    }
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
          log.warning('WebSocket close failed: ${error.runtimeType}');
        }, test: (Object error) => error is Exception),
      );
    }
  }

  void _handleError(dynamic error) {
    if (error is Error) {
      disconnect();
      throw error;
    }
    log.warning('WebSocket error: ${error.runtimeType}');
    _handleDisconnect();
  }

  void disconnect() {
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
