import 'package:bb_mobile/core/sync/sync_kind.dart';

class SyncCoordinatorState {
  const SyncCoordinatorState({
    this.running,
    this.queued = const {},
    this.errors = const {},
  });

  final SyncKind? running;
  final Set<SyncKind> queued;

  /// Errors collected during the current/most-recent drain pass, keyed by the
  /// kind that failed. Cleared when a new drain pass begins.
  final Map<SyncKind, Object> errors;

  bool get isBusy => running != null || queued.isNotEmpty;
}

/// Thrown by [SyncCoordinator.sync] when any of the requested kinds failed
/// during the drain pass that satisfied the call.
class SyncCoordinatorException implements Exception {
  const SyncCoordinatorException(this.failures);

  final Map<SyncKind, Object> failures;

  @override
  String toString() =>
      'SyncCoordinatorException(${failures.entries.map((e) => '${e.key}: ${e.value.runtimeType}').join(', ')})';
}
