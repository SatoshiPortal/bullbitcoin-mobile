import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ExchangeNotificationDatasource {
  final String _baseUrl;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;
  bool _isConnecting = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;

  ExchangeNotificationDatasource({
    required String baseUrl,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  }) : _baseUrl = baseUrl,
       _apiKeyDatasource = apiKeyDatasource,
       _isTestnet = isTestnet;

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
    if (_isConnected || _isConnecting) {
      log.info('WebSocket already connected or connecting');
      return;
    }
    _isConnecting = true;
    _isManuallyDisconnected = false;

    try {
      // Verify API key exists - don't attempt connection if not authenticated
      final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
      if (apiKey == null || !apiKey.isActive) {
        _isConnecting = false;
        _isManuallyDisconnected = true; // Prevent auto-reconnect loop
        log.fine('WebSocket connection skipped: user not authenticated');
        return;
      }

      // Build WebSocket URL
      final fullUrl = _buildWebSocketUrl();
      log.info('Base URL: $_baseUrl');
      log.info('Built WebSocket URL: $fullUrl');

      // Parse and verify URI
      final uri = Uri.parse(fullUrl);
      log.info(
        'Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path}',
      );

      // Use IOWebSocketChannel to pass X-API-Key header
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {'X-API-Key': apiKey.key},
      );

      // Wait for the connection to be ready
      await _channel!.ready;

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _isConnecting = false;
      log.info('WebSocket connected successfully');
    } catch (e) {
      _isConnecting = false;
      final errorStr = e.toString();

      // Don't auto-reconnect if server doesn't support WebSocket upgrade
      if (errorStr.contains('not upgraded to websocket')) {
        log.warning(
          'WebSocket endpoint not available - server may not support WebSocket on this endpoint. '
          'Disabling auto-reconnect.',
        );
        _isManuallyDisconnected = true; // Prevent auto-reconnect
      }

      log.severe(
        message: 'WebSocket connection failed',
        error: e,
        trace: StackTrace.current,
      );
      _handleDisconnect();
      rethrow;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final parsed = message is String
          ? jsonDecode(message) as Map<String, dynamic>
          : message as Map<String, dynamic>;
      log.fine('WebSocket message received: $parsed');
      _messageController.add(parsed);
    } catch (e) {
      log.warning('Error parsing WebSocket message: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    log.info('WebSocket disconnected');

    // AUTO-RECONNECT after 5 seconds (unless manually disconnected)
    if (!_isManuallyDisconnected) {
      log.info('Scheduling WebSocket auto-reconnect in 5 seconds...');
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isManuallyDisconnected && !_isConnecting) {
          log.info('Attempting WebSocket auto-reconnect...');
          connect();
        }
      });
    }
  }

  void _handleError(dynamic error) {
    log.severe(
      message: 'WebSocket error',
      error: error,
      trace: StackTrace.current,
    );
    _handleDisconnect();
  }

  void disconnect() {
    _isManuallyDisconnected = true;
    _isConnecting = false;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    log.info('WebSocket manually disconnected');
  }

  Future<void> reconnect() async {
    disconnect();
    _isManuallyDisconnected = false;
    await Future.delayed(const Duration(seconds: 1));
    await connect();
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
