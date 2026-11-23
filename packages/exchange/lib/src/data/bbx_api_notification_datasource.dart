import 'dart:async';

import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

typedef NotificationKeyReader = Future<Result<String?, Failure>> Function();

/// The exchange notification socket of one environment, on `bbx_api`.
///
/// The socket owns the connection, retries and frame decoding; this adapter
/// reads the API key, translates a credential-read failure into the socket's
/// own family and logs through the app logger. Only owned
/// [BbxNotification]s and [BbxFailure]s leave it: no frame reaches the app.
///
/// A handshake the server refuses with HTTP 401 means the key it read is no
/// longer valid: [onSessionRejected] is called, once per refused handshake.
class BbxApiNotificationDatasource {
  final BbxNotificationSocket _socket;
  final Bbx? _client;
  final StreamSubscription<Result<BbxNotification, BbxFailure>> _rejections;

  factory BbxApiNotificationDatasource({
    required String baseUrl,
    required NotificationKeyReader readApiKey,
    void Function()? onSessionRejected,
  }) {
    final client = Bbx.open(
      endpoint: baseUrl,
      readActiveApiKey: () => _apiKey(readApiKey),
      notificationLog: _log,
    );
    return BbxApiNotificationDatasource._(
      client.notifications,
      client,
      onSessionRejected,
    );
  }

  BbxApiNotificationDatasource._(
    this._socket,
    this._client,
    void Function()? onSessionRejected,
  ) : _rejections = _socket.events.listen((event) {
        if (event case Err(failure: BbxHttpFailure(status: 401))) {
          onSessionRejected?.call();
        }
      });

  /// Keeps the adapter's credential and log mapping under test while the BBX
  /// testing library owns the foreign channel. Production uses [Bbx.open].
  @visibleForTesting
  BbxApiNotificationDatasource.forTesting({
    required String baseUrl,
    required NotificationKeyReader readApiKey,
    required BbxNotificationSocket Function(
      String baseUrl,
      Future<Result<String?, BbxFailure>> Function() readApiKey,
      BbxNotificationLog log,
    )
    openSocket,
    void Function()? onSessionRejected,
  }) : this._(
         openSocket(baseUrl, () => _apiKey(readApiKey), _log),
         null,
         onSessionRejected,
       );

  /// Reads the app credential as the socket's own failure family: a missing
  /// key is `Ok(null)` (signed out, no retry) and a storage failure is
  /// [BbxCredentialUnavailableFailure], which retries like any other failure.
  static Future<Result<String?, BbxFailure>> _apiKey(
    NotificationKeyReader readApiKey,
  ) async => switch (await readApiKey()) {
    Ok(:final value) => Ok(value),
    Err() => const Err(BbxCredentialUnavailableFailure()),
  };

  static void _log(
    BbxNotificationLogLevel level,
    String message, {
    Type? error,
  }) {
    switch (level) {
      case BbxNotificationLogLevel.fine:
        log.fine(message, error: error);
      case BbxNotificationLogLevel.info:
        log.info(message, error: error);
      case BbxNotificationLogLevel.warning:
        log.warning(message, error: error);
    }
  }

  /// A decoded notification per valid frame, and a [BbxFailure] per malformed
  /// frame or failed connection.
  Stream<Result<BbxNotification, BbxFailure>> get events => _socket.events;

  bool get isConnected => _socket.isConnected;

  Future<Result<void, BbxFailure>> connect() => _socket.connect();

  void disconnect() => _socket.disconnect();

  Future<Result<void, BbxFailure>> reconnect() => _socket.reconnect();

  void dispose() {
    unawaited(_rejections.cancel());
    if (_client case final client?) {
      client.dispose();
    } else {
      _socket.dispose();
    }
  }
}
