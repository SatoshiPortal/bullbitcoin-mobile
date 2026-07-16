import 'package:bb_mobile/core/sync/sync_coordinator.dart';

final class WatchSuccessfulForegroundSyncsUsecase {
  final SyncCoordinator _coordinator;

  const WatchSuccessfulForegroundSyncsUsecase(this._coordinator);

  Stream<void> execute() => _coordinator.successfulSyncs;
}
