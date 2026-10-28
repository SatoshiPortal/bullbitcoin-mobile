import 'package:bbx_api/bbx_api.dart' as bbx;

/// The exchange's WebSocket notification channel, one per environment.
abstract interface class ExchangeNotificationDatasource {
  Stream<bbx.NotificationMessage> get messageStream;

  bool get isConnected;

  Future<void> connect();

  void disconnect();

  Future<void> reconnect();

  void dispose();
}
