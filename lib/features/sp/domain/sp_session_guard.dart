import 'dart:async';

/// Serializes complete SP establishment and teardown operations: ensure,
/// create, backend-config save (recreate), and wallet delete (revoke).
/// Recreate rollback already owns this non-reentrant guard and establishes
/// internally without acquiring it again.
///
/// The two are reachable at the same time from different screens (the SP
/// settings screen drives both, and turning developer mode off revokes from the
/// app settings screen), so disabling a button on one of them cannot keep them
/// apart. The loser waits rather than being refused: a revoke that gave up
/// would leave developer mode off with a live wallet still on disk.
///
/// Registered as a singleton, because the use cases holding it are factories
/// and a per-instance field would exclude nothing.
class SpSessionGuard {
  Future<void>? _tail;

  /// Run [body] once every earlier caller has finished. A failing body is
  /// swallowed for the queue only, so one failure does not poison the rest;
  /// the caller still gets its own error.
  Future<T> exclusive<T>(Future<T> Function() body) {
    // Create the initial future in the first caller's scheduling zone.
    final result = (_tail ?? Future<void>.value()).then((_) => body());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}
