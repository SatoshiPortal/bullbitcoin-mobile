import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Read the complete catalog selection before reconciling queue state. A failed or pending read must not make a disabled wallet look deleted to the queue. These are admission stamps, not evidence of the revision a writer failed on.
Future<Result<List<WalletRevision>, TransactionSyncFailure>> readWalletSyncJobs(
  Iterable<WalletKey> keys,
  WalletRevisionReader revisions,
) async {
  final jobs = <WalletRevision>[];
  for (final key in keys) {
    switch (await revisions.read(key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.stamp.key != key) {
          return const Err(TransactionSyncInvalidCatalogFailure());
        }
        switch (value.lifecycle) {
          case WalletLifecycle.active:
            jobs.add(value.stamp);
          case WalletLifecycle.pendingWrite:
            return const Err(TransactionSyncBusyFailure());
          case WalletLifecycle.deleted:
            break;
        }
    }
  }
  return Ok(List.unmodifiable(jobs));
}
