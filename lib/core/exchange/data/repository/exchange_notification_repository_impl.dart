import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_notification_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';

/// The `try/catch` boundary for the notification socket.
///
/// The service below throws on a refused or dropped connection; nothing above
/// this class sees that.
class ExchangeNotificationRepositoryImpl
    implements ExchangeNotificationRepository {
  final ExchangeNotificationService _exchangeNotificationService;

  const ExchangeNotificationRepositoryImpl({
    required this._exchangeNotificationService,
  });

  @override
  Stream<NotificationMessage> get messages =>
      _exchangeNotificationService.messageStream;

  @override
  Future<Result<void, ExchangeNotificationFailure>> connect() async {
    try {
      await _exchangeNotificationService.connect();
      return const Ok(null);
    } catch (e, st) {
      // Best-effort: a warning, not a bug.
      log.warning(
        'WebSocket connection failed',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        ExchangeNotificationConnectFailure('connect failed: ${e.runtimeType}'),
      );
    }
  }

  @override
  Future<Result<void, ExchangeNotificationFailure>> reconnect() async {
    try {
      await _exchangeNotificationService.reconnect();
      return const Ok(null);
    } catch (e, st) {
      log.warning(
        'WebSocket reconnection failed',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        ExchangeNotificationConnectFailure(
          'reconnect failed: ${e.runtimeType}',
        ),
      );
    }
  }

  @override
  void disconnect() => _exchangeNotificationService.disconnect();
}
