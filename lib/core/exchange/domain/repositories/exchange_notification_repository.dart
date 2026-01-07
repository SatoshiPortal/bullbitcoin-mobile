import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';

abstract class ExchangeNotificationRepository {
  Future<void> connect();
  void disconnect();
  Stream<NotificationMessage> get messageStream;
  bool get isConnected;
  Future<void> reconnect();
}

