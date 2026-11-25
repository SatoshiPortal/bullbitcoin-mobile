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

  final _messageController =
      StreamController<
        Result<NotificationMessage, ExchangeFailure>
      >.broadcast();

  StreamSubscription<Result<BbxNotification, BbxFailure>>? _mainnetSubscription;
  StreamSubscription<Result<BbxNotification, BbxFailure>>? _testnetSubscription;

  /// The environment of the socket the caller asked for; only [connect] and
  /// [disconnect] change it, never a read.
  ExchangeEnvironment? _connected;
  int _generation = 0;

  ExchangeNotificationService({
    required this._mainnetDatasource,
    required this._testnetDatasource,
  }) {
    _setupInternalListeners();
  }

  void _setupInternalListeners() {
    // Forward a socket's events only while it is the one asked for.
    _mainnetSubscription = _mainnetDatasource.events.listen((event) {
      if (_connected == ExchangeEnvironment.mainnet) _forward(event);
    });

    _testnetSubscription = _testnetDatasource.events.listen((event) {
      if (_connected == ExchangeEnvironment.testnet) _forward(event);
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

  /// Connects the socket of [environment] (the session's) and closes the
  /// other one, without holding the access queue during the handshake.
  Future<Result<void, ExchangeFailure>> connect(
    ExchangeEnvironment environment,
  ) async {
    final generation = ++_generation;
    _connected = environment;
    final datasource = switch (environment) {
      ExchangeEnvironment.mainnet => _mainnetDatasource,
      ExchangeEnvironment.testnet => _testnetDatasource,
    };
    final other = switch (environment) {
      ExchangeEnvironment.mainnet => _testnetDatasource,
      ExchangeEnvironment.testnet => _mainnetDatasource,
    };
    other.disconnect();
    final result = await datasource.connect();
    if (generation != _generation) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return result.mapErr(
      (_) => const ExchangeNotificationsUnavailableFailure(),
    );
  }

  /// Disconnect from both mainnet and testnet WebSockets
  void disconnect() {
    _generation++;
    _connected = null;
    _mainnetDatasource.disconnect();
    _testnetDatasource.disconnect();
  }

  /// Single stream of notification messages from the active network
  Stream<Result<NotificationMessage, ExchangeFailure>> get messageStream =>
      _messageController.stream;

  bool get isConnected => switch (_connected) {
    ExchangeEnvironment.mainnet => _mainnetDatasource.isConnected,
    ExchangeEnvironment.testnet => _testnetDatasource.isConnected,
    null => false,
  };

  /// Closes both sockets and opens the one of [environment] again, as after
  /// the platform dropped it.
  Future<Result<void, ExchangeFailure>> reconnect(
    ExchangeEnvironment environment,
  ) async {
    disconnect();
    final generation = _generation;
    await Future.delayed(const Duration(milliseconds: 500));
    if (generation != _generation) {
      return const Err(ExchangeOperationStaleFailure());
    }
    return connect(environment);
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
