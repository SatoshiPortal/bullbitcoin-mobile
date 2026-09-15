import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// The notification socket, as the cubit needs it.
///
/// No `try/catch` here: the repository is the boundary and already logged the
/// raw reason. The lifted failure exists so a caller *could* react, though the
/// socket is best-effort and the cubit deliberately does not surface it.
class WatchExchangeNotificationsUsecase {
  /// Message types that mean the cached account is stale.
  static const _accountChangeTypes = {'balance', 'group', 'kyc'};

  final ExchangeNotificationRepository _exchangeNotificationRepository;

  const WatchExchangeNotificationsUsecase({
    required this._exchangeNotificationRepository,
  });

  /// Emits whenever the server says the account may have changed.
  Stream<NotificationMessage> accountChanges() =>
      _exchangeNotificationRepository.messages.where(
        (message) => _accountChangeTypes.contains(message.type),
      );

  @useResult
  Future<Result<void, ExchangeFailure>> connect() async =>
      (await _exchangeNotificationRepository.connect()).mapErr(
        (failure) =>
            ExchangeNotificationsUnavailableFailure(failure.logMessage),
      );

  @useResult
  Future<Result<void, ExchangeFailure>> reconnect() async =>
      (await _exchangeNotificationRepository.reconnect()).mapErr(
        (failure) =>
            ExchangeNotificationsUnavailableFailure(failure.logMessage),
      );

  void disconnect() => _exchangeNotificationRepository.disconnect();
}
