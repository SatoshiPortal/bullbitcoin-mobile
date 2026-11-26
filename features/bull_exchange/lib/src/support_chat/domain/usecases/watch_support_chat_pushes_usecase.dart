import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// The exchange's pushes that say the support chat has a new message.
/// Other pushes and socket failures are left out: the chat re-reads only on
/// a message push.
class WatchSupportChatPushesUsecase {
  final Exchange _exchange;

  const WatchSupportChatPushesUsecase(this._exchange);

  Stream<NotificationMessage> execute() => _exchange.notifications
      .map(
        (event) => switch (event) {
          Ok(:final value) when value.kind == NotificationMessageKind.message =>
            value,
          Ok() || Err() => null,
        },
      )
      .where((message) => message != null)
      .cast<NotificationMessage>();
}
