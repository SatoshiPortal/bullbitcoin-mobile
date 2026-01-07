import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ExchangeNotificationUsecase {
  final ExchangeNotificationRepository _mainnetNotificationRepository;
  final ExchangeNotificationRepository _testnetNotificationRepository;
  final SettingsRepository _settingsRepository;

  final StreamController<NotificationMessage> _messageController =
      StreamController<NotificationMessage>.broadcast();

  StreamSubscription<NotificationMessage>? _mainnetSubscription;
  StreamSubscription<NotificationMessage>? _testnetSubscription;
  bool _isTestnet = false;

  ExchangeNotificationUsecase({
    required ExchangeNotificationRepository mainnetNotificationRepository,
    required ExchangeNotificationRepository testnetNotificationRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetNotificationRepository = mainnetNotificationRepository,
       _testnetNotificationRepository = testnetNotificationRepository,
       _settingsRepository = settingsRepository {
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
    // Listen to mainnet and forward messages only when on mainnet
    _mainnetSubscription = _mainnetNotificationRepository.messageStream.listen((
      message,
    ) {
      if (!_isTestnet) {
        _messageController.add(message);
      }
    });

    // Listen to testnet and forward messages only when on testnet
    _testnetSubscription = _testnetNotificationRepository.messageStream.listen((
      message,
    ) {
      if (_isTestnet) {
        _messageController.add(message);
      }
    });
  }

  Future<ExchangeNotificationRepository> _getRepository() async {
    final settings = await _settingsRepository.fetch();
    _isTestnet = settings.environment.isTestnet;
    return _isTestnet
        ? _testnetNotificationRepository
        : _mainnetNotificationRepository;
  }

  /// Connect to the WebSocket for the current environment (mainnet/testnet)
  Future<void> connect() async {
    final repo = await _getRepository();
    await repo.connect();
  }

  /// Disconnect from both mainnet and testnet WebSockets
  void disconnect() {
    _mainnetNotificationRepository.disconnect();
    _testnetNotificationRepository.disconnect();
  }

  /// Single stream of notification messages from the active network
  Stream<NotificationMessage> get messageStream => _messageController.stream;

  /// Check if the current environment's WebSocket is connected
  Future<bool> get isConnected async {
    final repo = await _getRepository();
    return repo.isConnected;
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
