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
/// The wallet-owned coordinator throws `SyncCoordinatorException` aggregating
/// per-kind failures. This usecase maps those to a typed wallet failure.
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
