import 'package:transaction_sync/read.dart';
import 'package:transaction_sync/transaction_sync.dart'
    show TransactionSyncBusyFailure;
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

/// Runs a wallet sync round.
///
/// [SyncCoordinator] is a shared core service, not a repository, so there is
/// no repository boundary to push this into: this use case — the first layer
/// the wallet feature owns — is it. The coordinator throws
/// `SyncCoordinatorException` aggregating per-kind failures; that stays in the
/// log and only a typed failure comes out (#1895).
class SyncWalletsUsecase {
  final SyncCoordinator _syncCoordinator;

  const SyncWalletsUsecase(this._syncCoordinator);

  @useResult
  Future<Result<void, WalletFailure>> execute({
    SyncTrigger trigger = SyncTrigger.automatic,
  }) async {
    try {
      await _syncCoordinator.sync(trigger: trigger);
      return const Ok(null);
    } catch (e) {
      if (e is SyncCoordinatorException &&
          e.failures.isNotEmpty &&
          e.failures.values.every(
            (failure) =>
                failure is WalletSnapshotException &&
                failure.failure is TransactionSyncBusyFailure,
          )) {
        return const Err(WalletSyncBusyFailure());
      }
      // The engine owns the failure diagnostic; coalesced callers only map it.
      return Err(WalletSyncFailure('sync: ${e.runtimeType}'));
    }
  }
}
