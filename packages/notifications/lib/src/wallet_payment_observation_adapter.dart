import 'package:meta/meta.dart';
import 'domain/local_notification.dart';
import 'domain/notifications_failure.dart';
import 'notifications_facade.dart';
import 'wallet_payment_notification_identity.dart';
import 'package:primitives/primitives.dart';

import 'wallet_sync_completion.dart';

/// Consumes writer completions only. Resume/revision readers must not call it.
final class WalletPaymentObservationAdapter {
  final NotificationsFacade notifications;
  const WalletPaymentObservationAdapter(this.notifications);

  @useResult
  Future<Result<void, NotificationsFailure>> recordCompletion(
    WalletSyncCompletion completion,
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
      completion.incomingTxids.map(event).toList(),
      onlyNew: true,
      baselineEvents: completion.incomingTxids.map(event).toList(),
    );
  }
}
