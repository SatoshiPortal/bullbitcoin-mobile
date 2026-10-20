import 'dart:async';

import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/notification_message_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

/// Selects the current environment and forwards only its notifications.
class ExchangeNotificationService {
  final ExchangeNotificationDatasource _mainnetDatasource;
  final ExchangeNotificationDatasource _testnetDatasource;
  final SettingsRepository _settingsRepository;

  final StreamController<NotificationMessage> _messageController =
      StreamController<NotificationMessage>.broadcast();

  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  ExchangeNotificationDatasource? _activeDatasource;
  // Invalidates pending settings lookups and delayed reconnects.
  int _requestNumber = 0;
  bool _disposed = false;

  ExchangeNotificationService({
    required this._mainnetDatasource,
    required this._testnetDatasource,
    required this._settingsRepository,
  });

  Stream<NotificationMessage> get messageStream => _messageController.stream;

  /// Connect to the WebSocket for the current environment (mainnet/testnet)
  Future<void> connect() async {
    if (_disposed) return;
    final request = ++_requestNumber;
    final datasource = await _getDatasource();
    if (_disposed || request != _requestNumber) return;
    _select(datasource);
    await datasource.connect();
  }

  /// Disconnect from both mainnet and testnet WebSockets
  void disconnect() {
    ++_requestNumber;
    _stopListening();
    _activeDatasource = null;
    _mainnetDatasource.disconnect();
    _testnetDatasource.disconnect();
  }

  /// Check if the current environment's WebSocket is connected
  Future<bool> get isConnected async {
    if (_disposed) return false;
    final request = _requestNumber;
    final datasource = await _getDatasource();
    return !_disposed &&
        request == _requestNumber &&
        identical(_activeDatasource, datasource) &&
        datasource.isConnected;
  }

  /// Reconnect to the WebSocket for the current environment
  /// Call this when the network changes to switch connections
  Future<void> reconnect() async {
    if (_disposed) return;
    disconnect();
    final request = _requestNumber;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_disposed || request != _requestNumber) return;
    await connect();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    unawaited(_messageController.close());
  }

  void _select(ExchangeNotificationDatasource datasource) {
    if (identical(_activeDatasource, datasource)) return;
    _stopListening();
    _activeDatasource?.disconnect();
    _activeDatasource = datasource;
    _messageSubscription = datasource.messageStream.listen((json) {
      final message = NotificationMessageModel.fromJson(json).toEntity();
      _messageController.add(message);
    });
  }

  void _stopListening() {
    final subscription = _messageSubscription;
    _messageSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<ExchangeNotificationDatasource> _getDatasource() async {
    final settings = await _settingsRepository.fetch();
    return settings.environment.isTestnet
        ? _testnetDatasource
        : _mainnetDatasource;
  }
}
