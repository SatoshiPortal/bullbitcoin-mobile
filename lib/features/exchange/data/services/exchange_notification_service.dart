import 'dart:async';

import 'package:bb_mobile/features/exchange/data/bbx_api_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:preferences/preferences.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';

/// Primary/driving adapter that receives WebSocket notification events
/// and exposes them as a stream for the application to consume.
///
/// This service listens to WebSocket events from the exchange API and routes
/// them based on the current environment (mainnet/testnet).
class ExchangeNotificationService {
  final BbxApiNotificationDatasource _mainnetDatasource;
  final BbxApiNotificationDatasource _testnetDatasource;
  final Preferences _settingsRepository;

  final StreamController<NotificationMessage> _messageController =
      StreamController<NotificationMessage>.broadcast();

  StreamSubscription<Result<BbxNotification, BbxFailure>>? _mainnetSubscription;
  StreamSubscription<Result<BbxNotification, BbxFailure>>? _testnetSubscription;
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
    _mainnetSubscription = _mainnetDatasource.events.listen((event) {
      if (!_isTestnet) _forward(event);
    });

    // Listen to testnet and forward messages only when on testnet
    _testnetSubscription = _testnetDatasource.events.listen((event) {
      if (_isTestnet) _forward(event);
    });
  }

  /// Forwards one owned event, or records a dropped one.
  ///
  /// The socket already bounds its connection-failure diagnostics, so only a
  /// malformed event is persisted here; connection retries stay console-only.
  /// Neither the frame nor the server's text is kept.
  void _forward(Result<BbxNotification, BbxFailure> event) {
    switch (event) {
      case Ok(:final value):
        _messageController.add(
          NotificationMessage(
            kind: _kind(value.kind),
            orderId: value.orderId,
            event: value.event,
          ),
        );
      case Err(:final failure):
        const message = 'WebSocket notification dropped';
        if (failure is BbxResponseFormatFailure) {
          log.fine(message, error: failure.runtimeType);
        } else {
          log.info(message, error: failure.runtimeType);
        }
    }
  }

  /// Maps the socket's owned kind to the app's, with an explicit case per
  /// value so a new kind has to be placed deliberately.
  static NotificationMessageKind _kind(BbxNotificationKind kind) =>
      switch (kind) {
        BbxNotificationKind.balance => NotificationMessageKind.balance,
        BbxNotificationKind.group => NotificationMessageKind.group,
        BbxNotificationKind.kyc => NotificationMessageKind.kyc,
        BbxNotificationKind.userPreferences =>
          NotificationMessageKind.userPreferences,
        BbxNotificationKind.message => NotificationMessageKind.message,
        BbxNotificationKind.order => NotificationMessageKind.order,
        BbxNotificationKind.limitOrder => NotificationMessageKind.limitOrder,
        BbxNotificationKind.user => NotificationMessageKind.user,
        BbxNotificationKind.recipient => NotificationMessageKind.recipient,
        BbxNotificationKind.unknown => NotificationMessageKind.unknown,
      };

  Future<BbxApiNotificationDatasource> _getDatasource() async {
    final settings = (await _settingsRepository.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    _isTestnet = settings.environment.requireHistoricalTestnet();
    return _isTestnet ? _testnetDatasource : _mainnetDatasource;
  }

  /// Connect to the WebSocket for the current environment (mainnet/testnet)
  ///
  /// The datasource reports a failed attempt on its event stream and in its own
  /// diagnostics, so this keeps the legacy completed-future contract its
  /// callers rely on.
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
