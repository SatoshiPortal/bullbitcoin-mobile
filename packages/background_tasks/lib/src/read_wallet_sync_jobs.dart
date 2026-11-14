import 'dart:collection';

import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Catalog membership is independent of whether a wallet is ready to sync.
final class WalletSyncJobSelection extends IterableBase<WalletRevision> {
  final List<WalletRevision> ready;
  final List<WalletKey> unavailable;

  WalletSyncJobSelection(
    Iterable<WalletRevision> ready,
    Iterable<WalletKey> unavailable,
  ) : ready = List.unmodifiable(ready),
      unavailable = List.unmodifiable(unavailable);

  @override
  Iterator<WalletRevision> get iterator => ready.iterator;
}

Future<Result<WalletSyncJobSelection, TransactionSyncFailure>>
readWalletSyncJobs(
  Iterable<WalletKey> keys,
  WalletRevisionReaderPort revisions,
) async {
  final jobs = <WalletRevision>[];
  final unavailable = <WalletKey>[];
  for (final key in keys) {
    switch (await revisions.read(key)) {
      case Err(
        failure: TransactionSyncNotFoundFailure() ||
            TransactionSyncBusyFailure(),
      ):
        unavailable.add(key);
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
            unavailable.add(key);
          case WalletLifecycle.deleted:
            break;
        }
    }
  }
  return Ok(WalletSyncJobSelection(jobs, unavailable));
}
