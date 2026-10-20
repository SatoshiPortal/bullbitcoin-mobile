import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient;

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ExchangeNotificationDatasource {
  // A missed pong closes the socket, so a connection the OS dropped silently
  // reaches _handleDisconnect and auto-reconnects.
  static const _pingInterval = Duration(seconds: 30);

  final String _baseUrl;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;
  final WebSocketChannel Function(Uri, Map<String, dynamic>)? _openChannel;
  final bool Function() _isForeground;

  WebSocketChannel? _channel;
  HttpClient? _httpClient;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _generation = 0;
  int _retrySeconds = 5;
  bool _disposed = false;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;
  bool _isConnecting = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;

  ExchangeNotificationDatasource({
    required this._baseUrl,
    required this._apiKeyDatasource,
    required this._isTestnet,
    this._openChannel,
    bool Function()? isForeground,
  }) : _isForeground = isForeground ?? _allowConnection;

  static bool _allowConnection() => true;

  WebSocketChannel _connectChannel(Uri uri, Map<String, dynamic> headers) {
    final openChannel = _openChannel;
    if (openChannel != null) return openChannel(uri, headers);
    // Own the HTTP client so disconnect/timeout also aborts an in-flight
    // upgrade. A Future timeout alone leaves the underlying request alive.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    _httpClient = client;
    return IOWebSocketChannel.connect(
      uri,
      headers: headers,
      pingInterval: _pingInterval,
      connectTimeout: const Duration(seconds: 15),
      customClient: client,
    );
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

  Future<void> connect() async {
    if (_disposed || !_isForeground() || _isConnected || _isConnecting) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnecting = true;
    _isManuallyDisconnected = false;
    final generation = ++_generation;

    try {
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (!_isCurrent(generation)) return;
      if (!_isForeground()) {
        disconnect();
        return;
      }
      if (apiKey == null || !apiKey.isActive) {
        _isConnecting = false;
        _isManuallyDisconnected = true;
        log.fine('WebSocket connection skipped: user not authenticated');
        return;
      }

      final uri = Uri.parse(_buildWebSocketUrl());
      final channel = _connectChannel(uri, {'X-API-Key': apiKey.key});
      _channel = channel;
      // Subscribe before awaiting ready: connection failures are also emitted
      // on the stream, including when the handshake has been cancelled.
      _subscription = channel.stream.listen(
        (message) {
          if (_isCurrent(generation) && _isForeground()) {
            _handleMessage(message);
          }
        },
        onError: (Object error, StackTrace trace) {
          if (!_isCurrent(generation)) return;
          if (error is Error) {
            log.severe(
              message: 'WebSocket stream error',
              error: error,
              trace: trace,
            );
            _isManuallyDisconnected = true;
            _handleDisconnect(generation);
            return;
          }
          _connectionFailed(error, generation);
        },
        onDone: () => _handleDisconnect(generation),
      );
      await channel.ready;
      if (!_isCurrent(generation)) return;
      if (!_isForeground()) {
        disconnect();
        return;
      }

      _isConnected = true;
      _isConnecting = false;
      _retrySeconds = 5;
      log.fine('WebSocket connected successfully');
    } on Exception catch (e) {
      if (_isCurrent(generation)) _connectionFailed(e, generation);
    } finally {
      // Release an attempt that exits with a programmer error, without
      // catching that error or touching a newer connection.
      if (generation == _generation && _isConnecting) {
        ++_generation;
        _isConnecting = false;
        _closeChannel();
      }
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && !_isManuallyDisconnected && generation == _generation;

  void _connectionFailed(Object error, int generation) {
    if (error.toString().contains('not upgraded to websocket')) {
      _isManuallyDisconnected = true;
      log.warning('WebSocket endpoint unavailable; auto-reconnect disabled');
    } else {
      log.warning(
        'WebSocket connection failed (foreground=${_isForeground()})',
        error: error,
      );
    }
    _handleDisconnect(generation);
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

  void _closeChannel() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final channel = _channel;
    _channel = null;
    final client = _httpClient;
    _httpClient = null;
    client?.close(force: true);
    if (channel != null) {
      unawaited(
        channel.sink.close().catchError((Object error) {
          log.warning('WebSocket close failed: ${error.runtimeType}');
        }),
      );
    }
  }

  void _handleDisconnect(int generation) {
    if (generation != _generation) return;
    ++_generation;
    _isConnected = false;
    _isConnecting = false;
    _closeChannel();
    if (_disposed ||
        _isManuallyDisconnected ||
        !_isForeground() ||
        _reconnectTimer != null) {
      return;
    }

    final delay = Duration(seconds: _retrySeconds);
    _retrySeconds = (_retrySeconds * 2).clamp(5, 60);
    log.fine('WebSocket reconnect scheduled in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  void disconnect() {
    ++_generation;
    _retrySeconds = 5;
    _isManuallyDisconnected = true;
    _isConnecting = false;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeChannel();
  }

  Future<void> reconnect() async {
    if (_disposed) return;
    disconnect();
    final generation = _generation;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_disposed || generation != _generation) return;
    await connect();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    unawaited(_messageController.close());
  }
}
