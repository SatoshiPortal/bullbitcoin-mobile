import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/utils/logger.dart' show log;
import 'package:web_socket_channel/web_socket_channel.dart';

class ExchangeNotificationDatasource {
  final String _baseUrl;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isManuallyDisconnected = false;

  final _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  bool get isConnected => _isConnected;

  ExchangeNotificationDatasource({
    required String baseUrl,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  })  : _baseUrl = baseUrl,
        _apiKeyDatasource = apiKeyDatasource,
        _isTestnet = isTestnet;

  Future<void> connect() async {
    if (_isConnected) return;
    _isManuallyDisconnected = false;

    // Verify API key exists
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw Exception('API key not available for WebSocket connection');
    }

    // Build WebSocket URL
    final wsUrl = _baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    final fullUrl = '$wsUrl/api-commcenter';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(fullUrl));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      log.info('WebSocket connected to $fullUrl');
    } catch (e) {
      log.severe('WebSocket connection failed: $e');
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
    log.info('WebSocket disconnected');

    // AUTO-RECONNECT after 5 seconds (unless manually disconnected)
    if (!_isManuallyDisconnected) {
      log.info('Scheduling WebSocket auto-reconnect in 5 seconds...');
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isManuallyDisconnected) {
          log.info('Attempting WebSocket auto-reconnect...');
          connect();
        }
      });
    }
  }

  void _handleError(dynamic error) {
    log.severe('WebSocket error: $error');
    _handleDisconnect();
  }

  void disconnect() {
    _isManuallyDisconnected = true;
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

