import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

import 'domain/background_wallet_sync.dart';

/// Consumes writer completions only. Resume/revision readers must not call it.
final class WalletPaymentObservationAdapter {
  final NotificationsFacade notifications;
  const WalletPaymentObservationAdapter(this.notifications);

  Future<Result<void, NotificationsFailure>> recordCompletion(
    BackgroundSyncOutcome completion,
  ) async {
    if (!completion.completedInForeground) return const Ok(null);
    final key = completion.revision.key;
    LocalNotification event(String txid) =>
        WalletPaymentNotificationIdentity.event(
          key,
          txid,
          observedAt: completion.completedAt,
        );
    return notifications.recordObserved(
      WalletPaymentNotificationIdentity.topicId(key),
      completion.discoveredTxids.map(event).toList(),
      baselineEvents: completion.incomingTxids.map(event).toList(),
    );
  }
}
