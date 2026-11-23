import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' show SyncBusyFailure;
import 'package:overview/setup.dart';
import 'package:overview/overview.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:meta/meta.dart';

/// Runs a wallet sync round.
///
/// The Overview coordinator throws `SyncCoordinatorException` aggregating
/// per-kind failures. This usecase maps those to a typed wallet failure.
class SyncWalletsUsecase {
  final Future<void> Function({SyncTrigger trigger}) _sync;

  const SyncWalletsUsecase(this._sync);

  @useResult
  Future<Result<void, WalletFailure>> execute({
    SyncTrigger trigger = SyncTrigger.automatic,
  }) async {
    try {
      await _sync(trigger: trigger);
      return const Ok(null);
    } catch (e) {
      if (e is SyncCoordinatorException &&
          e.failures.isNotEmpty &&
          e.failures.values.every(
            (failure) =>
                failure is WalletSnapshotException &&
                failure.failure is SyncBusyFailure,
          )) {
        return const Err(WalletSyncBusyFailure());
      }
      // The engine owns the failure diagnostic; coalesced callers only map it.
      return Err(WalletSyncFailure('sync: ${e.runtimeType}'));
    }
  }
}
