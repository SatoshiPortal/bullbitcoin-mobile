import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_payment_observation_port.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Hands the transactions of a sync that ends while the app is visible to the
/// notification outbox as seen.
/// Notifications are registered after the wallet layer, and not at all on
/// platforms without them, so the facade is looked up at call time.
final class WalletPaymentObservationAdapter
    implements WalletPaymentObservationPort {
  final NotificationsFacade? Function() _notifications;
  final bool Function() _isAppVisible;

  const WalletPaymentObservationAdapter(
    this._notifications, {
    required this._isAppVisible,
  });

  @override
  Future<void> recordSeen(WalletNetworkKey key, List<String> txids) async {
    // A sync that ends after the user left was not seen: the background must
    // still announce its payments.
    if (!_isAppVisible()) return;
    final notifications = _notifications();
    if (notifications == null) return;
    final now = DateTime.now().toUtc();
    final result = await notifications
        .recordObserved(WalletPaymentNotificationIdentity.topicId(key), [
          for (final txid in txids)
            WalletPaymentNotificationIdentity.event(key, txid, observedAt: now),
        ]);
    switch (result) {
      case Ok():
        log.fine(
          'Wallet payments seen recorded chain=${key.chain} '
          'network=${key.network} count=${txids.length}',
        );
      case Err(:final failure):
        log.warning(
          'Wallet payments seen not recorded chain=${key.chain} '
          'category=${failure.runtimeType}',
        );
    }
  }
}
