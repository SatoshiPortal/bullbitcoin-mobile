import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:bull_logger/bull_logger.dart' show log;
import 'package:primitives/primitives.dart';

/// [ExchangeNotificationDatasource] on the `bbx_api` notification socket.
///
/// The socket owns the connection, retries and frame parsing; this adapter
/// reads the API key and logs through the app logger.
class BbxApiNotificationDatasource implements ExchangeNotificationDatasource {
  final BbxNotificationSocket _socket;

  BbxApiNotificationDatasource({
    required String baseUrl,
    required ReadExchangeApiKey readApiKey,
    BbxWebSocketConnector? connector,
  }) : _socket = BbxNotificationSocket(
         baseUrl: baseUrl,
         readApiKey: () => _apiKey(readApiKey),
         connector: connector,
         log: _log,
       );

  static Future<String?> _apiKey(ReadExchangeApiKey readApiKey) async {
    switch (await readApiKey()) {
      case Ok(:final value):
        return value;
      case Err(:final failure):
        throw ExchangeAuthenticationException(failure);
    }
  }

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

  @override
  Stream<Map<String, dynamic>> get messageStream => _socket.messages;

  @override
  bool get isConnected => _socket.isConnected;

  @override
  Future<void> connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  Future<void> reconnect() => _socket.reconnect();

  @override
  void dispose() => _socket.dispose();
}
