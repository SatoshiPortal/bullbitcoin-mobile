import 'dart:async';

/// Serializes the operations that tear the SP session down and rebuild it:
/// the backend-config save (recreate) and the wallet delete (revoke).
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
  Future<void> _tail = Future.value();

  /// Run [body] once every earlier caller has finished. A failing body is
  /// swallowed for the queue only, so one failure does not poison the rest;
  /// the caller still gets its own error.
  Future<T> exclusive<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}
