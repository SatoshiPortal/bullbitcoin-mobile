import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bbx_api/bbx_api.dart';

/// [ExchangeNotificationDatasource] on the `bbx_api` notification socket.
class BbxApiNotificationDatasource implements ExchangeNotificationDatasource {
  final NotificationSocketService _socket;

  BbxApiNotificationDatasource(this._socket);

  @override
  Stream<NotificationMessage> get messageStream => _socket.notifications;

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
