import 'package:bb_mobile/core/sync/sync_kind.dart';

class SyncCoordinatorState {
  const SyncCoordinatorState({this.running, this.queued = const {}});

  final SyncKind? running;
  final Set<SyncKind> queued;

  bool get isBusy => running != null || queued.isNotEmpty;
}
