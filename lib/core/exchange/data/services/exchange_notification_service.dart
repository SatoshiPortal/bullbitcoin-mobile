import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

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

  StreamSubscription<bbx.NotificationMessage>? _mainnetSubscription;
  StreamSubscription<bbx.NotificationMessage>? _testnetSubscription;
  bool _isTestnet = false;

  ExchangeNotificationService({
    required this._mainnetDatasource,
    required this._testnetDatasource,
    required this._settingsRepository,
  }) {
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
    // Listen to mainnet and forward messages only when on mainnet
    _mainnetSubscription = _mainnetDatasource.messageStream.listen((message) {
      if (!_isTestnet) _messageController.add(_toEntity(message));
    });

    // Listen to testnet and forward messages only when on testnet
    _testnetSubscription = _testnetDatasource.messageStream.listen((message) {
      if (_isTestnet) _messageController.add(_toEntity(message));
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

  static NotificationMessage _toEntity(bbx.NotificationMessage message) =>
      NotificationMessage(
        kind: switch (message.type) {
          bbx.NotificationType.balance => NotificationMessageKind.balance,
          bbx.NotificationType.group => NotificationMessageKind.group,
          bbx.NotificationType.kyc => NotificationMessageKind.kyc,
          bbx.NotificationType.userPreferences =>
            NotificationMessageKind.userPreferences,
          bbx.NotificationType.message => NotificationMessageKind.message,
          bbx.NotificationType.order => NotificationMessageKind.order,
          bbx.NotificationType.limitOrder => NotificationMessageKind.limitOrder,
          bbx.NotificationType.recipient => NotificationMessageKind.recipient,
          bbx.NotificationType.notification ||
          bbx.NotificationType.announcement ||
          bbx.NotificationType.unknown => NotificationMessageKind.unknown,
        },
        orderId: message.orderId,
        event: message.event,
        rawData: message.data,
      );
}
