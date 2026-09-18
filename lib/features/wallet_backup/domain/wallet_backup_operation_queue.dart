import 'dart:async';

/// Serializes this feature's publication, recovery and deletion mutations.
final class WalletBackupOperationQueue {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    return (() async {
      await previous;
      try {
        return await operation();
      } finally {
        finished.complete();
      }
    })();
  }
}
