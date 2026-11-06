import 'package:bull_logger/bull_logger.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Records actual sync completions. Snapshot readers never use this owner.
final class WalletPaymentObserver {
  final Future<NotificationsFacade> Function() _notifications;
  final bool Function() _isForeground;

  const WalletPaymentObserver(this._notifications, this._isForeground);

  Future<Result<void, TransactionSyncFailure>> record(
    SyncCompletion completion,
  ) async {
    // Capture before ANY await, including opening the durable outbox.
    final visible = _isForeground();
    final completedAt = DateTime.now();
    final revision = completion.revision;
    if (revision == null) return const Err(TransactionSyncStorageFailure());
    try {
      final adapter = WalletPaymentObservationAdapter(await _notifications());
      final result = await adapter.recordCompletion(
        WalletSyncCompletion(
          revision: revision,
          incomingTxids: completion.incomingTxids,
          discoveredTxids: completion.discoveredTxids,
          completedAt: completedAt,
          completedInForeground: visible,
        ),
      );
      if (result is Err) {
        log.warning('Payment observation persistence failed');
        return const Err(TransactionSyncStorageFailure());
      }
      log.fine(
        'Payment observation recorded foreground=$visible incoming=${completion.incomingTxids.length} discoveries=${completion.discoveredTxids.length} revision=${revision.revision}',
      );
      return const Ok(null);
    } on Exception {
      log.warning('Payment observation storage unavailable');
      return const Err(TransactionSyncStorageFailure());
    }
  }
}
