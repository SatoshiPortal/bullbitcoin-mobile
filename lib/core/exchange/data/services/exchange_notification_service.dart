import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/notification_message_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

/// Primary/driving adapter that receives WebSocket notification events
/// and exposes them as a stream for the application to consume.
///
/// This service listens to WebSocket events from the exchange API and routes
/// them based on the current environment (mainnet/testnet).
class ExchangeNotificationService {
  final ExchangeNotificationDatasource _mainnetDatasource;
  final ExchangeNotificationDatasource _testnetDatasource;
  final SettingsRepository _settingsRepository;

  final StreamController<NotificationMessage> _messageController =
      StreamController<NotificationMessage>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _mainnetSubscription;
  StreamSubscription<Map<String, dynamic>>? _testnetSubscription;
  bool _isTestnet = false;

  ExchangeNotificationService({
    required ExchangeNotificationDatasource mainnetDatasource,
    required ExchangeNotificationDatasource testnetDatasource,
    required SettingsRepository settingsRepository,
  }) : _mainnetDatasource = mainnetDatasource,
       _testnetDatasource = testnetDatasource,
       _settingsRepository = settingsRepository {
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
    // Listen to mainnet and forward messages only when on mainnet
    _mainnetSubscription = _mainnetDatasource.messageStream.listen((json) {
      if (!_isTestnet) {
        final entity = NotificationMessageModel.fromJson(json).toEntity();
        _messageController.add(entity);
      }
    });

    // Listen to testnet and forward messages only when on testnet
    _testnetSubscription = _testnetDatasource.messageStream.listen((json) {
      if (_isTestnet) {
        final entity = NotificationMessageModel.fromJson(json).toEntity();
        _messageController.add(entity);
      }
    });
  }

  Future<ExchangeNotificationDatasource> _getDatasource() async {
    final settings = await _settingsRepository.fetch();
    _isTestnet = settings.environment.isTestnet;
    return _isTestnet ? _testnetDatasource : _mainnetDatasource;
  }

  /// Connect to the WebSocket for the current environment (mainnet/testnet)
  Future<void> connect() async {
    final datasource = await _getDatasource();
    await datasource.connect();
  }

  /// Disconnect from both mainnet and testnet WebSockets
  void disconnect() {
    _mainnetDatasource.disconnect();
    _testnetDatasource.disconnect();
  }

  /// Single stream of notification messages from the active network
  Stream<NotificationMessage> get messageStream => _messageController.stream;

  /// Check if the current environment's WebSocket is connected
  Future<bool> get isConnected async {
    final datasource = await _getDatasource();
    return datasource.isConnected;
  }

  /// Reconnect to the WebSocket for the current environment
  /// Call this when the network changes to switch connections
  Future<void> reconnect() async {
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }

  void dispose() {
    _mainnetSubscription?.cancel();
    _testnetSubscription?.cancel();
    _messageController.close();
  }
}
