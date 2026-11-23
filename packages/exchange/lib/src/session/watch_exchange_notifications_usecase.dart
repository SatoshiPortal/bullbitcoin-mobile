import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';

/// The account changes the notification socket reports.
///
/// The socket itself is an effect of the signed-in access state: the access
/// lifecycle opens it when a session starts and closes it when it ends.
class WatchExchangeNotificationsUsecase {
  final Exchange _exchange;

  const WatchExchangeNotificationsUsecase({required this._exchange});

  /// Emits whenever the server says the account may have changed.
  Stream<NotificationMessage> accountChanges() =>
      _exchange.notifications.expand(
        (event) => switch (event) {
          Ok(value: final message)
              when switch (message.kind) {
                NotificationMessageKind.balance ||
                NotificationMessageKind.group ||
                NotificationMessageKind.kyc ||
                NotificationMessageKind.userPreferences => true,
                NotificationMessageKind.message ||
                NotificationMessageKind.order ||
                NotificationMessageKind.limitOrder ||
                NotificationMessageKind.user ||
                NotificationMessageKind.recipient ||
                NotificationMessageKind.unknown => false,
              } =>
            [message],
          Ok() || Err() => const [],
        },
      );
}
