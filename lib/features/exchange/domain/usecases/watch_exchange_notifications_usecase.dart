import '../repositories/exchange_access_repository.dart';
import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_notification_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';

/// The notification socket, as the cubit needs it.
///
/// No `try/catch` here: the repository is the boundary and already logged the
/// raw reason. The lifted failure exists so a caller *could* react, though the
/// socket is best-effort and the cubit deliberately does not surface it.
class WatchExchangeNotificationsUsecase {
  final ExchangeNotificationRepository _exchangeNotificationRepository;
  final ExchangeAccessRepository _access;

  const WatchExchangeNotificationsUsecase({
    required this._exchangeNotificationRepository,
    required this._access,
  });

  /// Emits whenever the server says the account may have changed.
  Stream<NotificationMessage> accountChanges() =>
      _exchangeNotificationRepository.messages.where(
        // The kinds that mean the cached account is stale. A `switch` rather
        // than a set, so a new kind has to be placed deliberately.
        (message) => switch (message.kind) {
          NotificationMessageKind.balance ||
          NotificationMessageKind.group ||
          NotificationMessageKind.kyc ||
          NotificationMessageKind.userPreferences => true,
          _ => false,
        },
      );

  Future<Result<void, ExchangeFailure>> _connect(bool reconnect) =>
      _access.runAuthenticated(() async {
        final result = reconnect
            ? await _exchangeNotificationRepository.reconnect()
            : await _exchangeNotificationRepository.connect();
        return result.mapErr(
          (failure) =>
              ExchangeNotificationsUnavailableFailure(failure.logMessage),
        );
      });

  Future<Result<void, ExchangeFailure>> connect() => _connect(false);
  Future<Result<void, ExchangeFailure>> reconnect() => _connect(true);

  void disconnect() => _exchangeNotificationRepository.disconnect();
}
