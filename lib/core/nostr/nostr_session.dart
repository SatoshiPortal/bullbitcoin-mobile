import 'dart:async';

/// Cancellation for one finite relay lookup or publication.
final class NostrSession {
  final Completer<void> _cancel = Completer<void>();
  bool get isCancelled => _cancel.isCompleted;
  Future<void> get cancelled => _cancel.future;

  void cancel() {
    if (!isCancelled) _cancel.complete();
  }
}
