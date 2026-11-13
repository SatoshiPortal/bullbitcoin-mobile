import 'dart:async';

/// Serializes wallet and secret mutations within one isolate.
///
/// Callbacks must await all nested mutations and must not detach work. The
/// same instance must be injected into every participant. The lock order is
/// the SP session guard followed by this guard, never the reverse.
class WalletMutationGuard {
  final Object _zoneKey = Object();
  Future<void> _tail = Future<void>.value();

  /// Register durable external callbacks without granting them reentrance.
  /// The current owner still holds its lock while awaiting an external call.
  T withoutReentrance<T>(T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: null});

  Future<T> exclusive<T>(Future<T> Function() action) async {
    final inherited = Zone.current[_zoneKey];
    if (inherited is _GuardToken && inherited.active) {
      return action();
    }
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    final token = _GuardToken();
    try {
      return await runZoned(action, zoneValues: {_zoneKey: token});
    } finally {
      token.active = false;
      done.complete();
    }
  }
}

class _GuardToken {
  bool active = true;
}
