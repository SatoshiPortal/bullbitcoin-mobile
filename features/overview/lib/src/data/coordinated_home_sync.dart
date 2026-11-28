import 'package:sync/sync.dart'
    show SyncBusyFailure, SyncFailure, WalletKey, WalletSnapshotException;

import '../domain/home_sync_pass.dart';
import '../domain/sync_trigger.dart';
import 'sync_coordinator.dart';

/// Gives Home the Overview coordinator's queue without leaking its exception
/// or the per-kind failure map into presentation.
final class CoordinatedHomeSync implements HomeSyncPass {
  final SyncCoordinator<WalletKey, SyncFailure> _coordinator;

  const CoordinatedHomeSync(this._coordinator);

  @override
  bool get isSyncPassActive => _coordinator.isSyncPassActive;

  @override
  Stream<bool> get activity => _coordinator.syncPassActivity;

  @override
  Future<HomeSyncOutcome> sync({required SyncTrigger trigger}) async {
    try {
      await _coordinator.sync(trigger: trigger);
      return HomeSyncOutcome.completed;
    } on SyncCoordinatorException catch (error) {
      final failures = error.failures.values;
      final onlyBusy =
          failures.isNotEmpty &&
          failures.every(
            (failure) =>
                failure is WalletSnapshotException &&
                failure.failure is SyncBusyFailure,
          );
      return onlyBusy ? HomeSyncOutcome.busy : HomeSyncOutcome.failed;
    } on Exception {
      return HomeSyncOutcome.failed;
    }
  }
}
