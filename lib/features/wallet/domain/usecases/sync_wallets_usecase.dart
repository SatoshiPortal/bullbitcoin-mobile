import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/features/wallet/domain/sync_trigger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
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
    } catch (e, st) {
      log.warning('SyncWallets: sync round failed', error: e, trace: st);
      return Err(WalletSyncFailure('sync: ${e.runtimeType}'));
    }
  }
}
