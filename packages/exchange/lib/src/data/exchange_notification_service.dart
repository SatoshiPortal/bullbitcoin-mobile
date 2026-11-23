import 'dart:async';

import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';

import '../domain/entities/notification_message.dart';
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';
import 'bbx_api_notification_datasource.dart';

/// Primary/driving adapter that receives WebSocket notification events
/// and exposes them as a stream for the application to consume.
///
/// This service listens to WebSocket events from the exchange API and routes
/// them based on the current environment (mainnet/testnet).
class ExchangeNotificationService {
  final BbxApiNotificationDatasource _mainnetDatasource;
  final BbxApiNotificationDatasource _testnetDatasource;
  final Future<Result<ExchangeEnvironment, ExchangeFailure>> Function()
  _readEnvironment;

  final _messageController =
      StreamController<
        Result<NotificationMessage, ExchangeFailure>
      >.broadcast();

  StreamSubscription<Result<BbxNotification, BbxFailure>>? _mainnetSubscription;
  StreamSubscription<Result<BbxNotification, BbxFailure>>? _testnetSubscription;
  bool _isTestnet = false;
  int _generation = 0;

  ExchangeNotificationService({
    required this._mainnetDatasource,
    required this._testnetDatasource,
    required this._readEnvironment,
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

  /// Forwards an owned message or a recoverable failure.
  ///
  /// The socket already bounds its connection-failure diagnostics, so only a
  /// malformed event is persisted here; connection retries stay console-only.
  /// Neither the frame nor the server's text is kept.
  void _forward(Result<BbxNotification, BbxFailure> event) {
    switch (event) {
      case Ok(:final value):
        _messageController.add(
          Ok(
            NotificationMessage(
              kind: _kind(value.kind),
              orderId: value.orderId,
              event: value.event,
            ),
          ),
        );
      case Err(:final failure):
        const message = 'WebSocket notification dropped';
        if (failure is BbxResponseFormatFailure) {
          log.fine(message, error: failure.runtimeType);
        } else {
          log.info(message, error: failure.runtimeType);
        }
        _messageController.add(
          const Err(ExchangeNotificationsUnavailableFailure()),
        );
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

  /// Connects without holding the access queue during a native handshake.
  Future<Result<void, ExchangeFailure>> connect() async {
    final generation = ++_generation;
    final environment = await _readEnvironment();
    if (generation != _generation) {
      return const Err(ExchangeOperationStaleFailure());
    }
    switch (environment) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        _isTestnet = value == ExchangeEnvironment.testnet;
        final datasource = _isTestnet ? _testnetDatasource : _mainnetDatasource;
        final other = _isTestnet ? _mainnetDatasource : _testnetDatasource;
        other.disconnect();
        final result = await datasource.connect();
        if (generation != _generation) {
          return const Err(ExchangeOperationStaleFailure());
        }
        return result.mapErr(
          (_) => const ExchangeNotificationsUnavailableFailure(),
        );
    }
  }

  /// Disconnect from both mainnet and testnet WebSockets
  void disconnect() {
    _generation++;
    _mainnetDatasource.disconnect();
    _testnetDatasource.disconnect();
  }

  /// Single stream of notification messages from the active network
  Stream<Result<NotificationMessage, ExchangeFailure>> get messageStream =>
      _messageController.stream;

  bool get isConnected =>
      (_isTestnet ? _testnetDatasource : _mainnetDatasource).isConnected;

  /// Reconnect to the WebSocket for the current environment
  /// Call this when the network changes to switch connections
  Future<Result<void, ExchangeFailure>> reconnect() async {
    disconnect();
    final generation = _generation;
    await Future.delayed(const Duration(milliseconds: 500));
    if (generation != _generation) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return connect();
  }

  Future<void> dispose() async {
    disconnect();
    await _mainnetSubscription?.cancel();
    await _testnetSubscription?.cancel();
    _mainnetDatasource.dispose();
    _testnetDatasource.dispose();
    await _messageController.close();
  }
}
