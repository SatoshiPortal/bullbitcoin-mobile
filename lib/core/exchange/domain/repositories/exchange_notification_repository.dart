import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_notification_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// The push-notification socket. Implementations are the `try/catch` boundary:
/// they log the raw reason and return a sanitized
/// [ExchangeNotificationFailure].
abstract interface class ExchangeNotificationRepository {
  Stream<NotificationMessage> get messages;

  @useResult
  Future<Result<void, ExchangeNotificationFailure>> connect();

  @useResult
  Future<Result<void, ExchangeNotificationFailure>> reconnect();

  void disconnect();
}
