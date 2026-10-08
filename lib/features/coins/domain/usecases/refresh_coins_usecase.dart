import 'package:bb_mobile/core/sync/sync_coordinator.dart';
import 'package:bb_mobile/core/sync/sync_trigger.dart';

class RefreshCoinsUsecase {
  final SyncCoordinator _syncCoordinator;

  RefreshCoinsUsecase(this._syncCoordinator);

  Future<void> execute() async {
    try {
      await _syncCoordinator.sync(trigger: SyncTrigger.user);
    } on SyncCoordinatorException {
      // The coordinator already records individual sync failures. Let the
      // caller reload local coins so pull-to-refresh still settles cleanly.
    }
  }
}
