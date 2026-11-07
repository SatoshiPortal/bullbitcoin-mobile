import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
      // The engine owns the failure diagnostic; coalesced callers only map it.
      return Err(WalletSyncFailure('sync: ${e.runtimeType}'));
    }
  }
}
