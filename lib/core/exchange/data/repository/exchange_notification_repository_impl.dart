import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/notification_message_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';

class ExchangeNotificationRepositoryImpl
    implements ExchangeNotificationRepository {
  final ExchangeNotificationDatasource _datasource;

  ExchangeNotificationRepositoryImpl({
    required ExchangeNotificationDatasource datasource,
  }) : _datasource = datasource;

  @override
  Future<void> connect() => _datasource.connect();

  @override
  void disconnect() => _datasource.disconnect();

  @override
  Stream<NotificationMessage> get messageStream => _datasource.messageStream
      .map((json) => NotificationMessageModel.fromJson(json).toEntity());

  @override
  bool get isConnected => _datasource.isConnected;

  @override
  Future<void> reconnect() => _datasource.reconnect();
}

