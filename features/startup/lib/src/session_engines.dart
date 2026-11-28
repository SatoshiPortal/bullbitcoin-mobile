import 'dart:async';

/// One engine that signs, reveals or spends and must not outlive a session.
///
/// [suspend] revokes synchronously, before its first `await`: after the call
/// returns nothing new starts. The future it returns completes only once the
/// engine is confirmed stopped. [resume] starts it again and is not called
/// before that confirmation.
final class SessionEngine {
  final String name;
  final Future<void> Function() suspend;
  final void Function() resume;

  const SessionEngine({
    required this.name,
    required this.suspend,
    required this.resume,
  });
}

/// Suspends every engine on lock and resumes each one once, for the session
/// that is current when its stop is confirmed.
///
/// - A timeout never reopens an engine: a late confirmation is awaited, with
///   no bound, and a second instance is never started beside the first.
/// - Each unlock or lock takes a new token. A resume scheduled for a token that
///   is no longer current does nothing, so `lock → unlock B → lock` before the
///   first stop is confirmed resumes nothing.
/// - An engine whose stop failed stays closed for the life of the process.
final class SessionEngines {
  final List<_Slot> _slots;
  final _unlocks = StreamController<void>.broadcast(sync: true);
  var _token = 0;
  var _locked = false;
  var _closed = false;

  SessionEngines(List<SessionEngine> engines)
    : _slots = [for (final engine in engines) _Slot(engine)];

  bool get isLocked => _locked;

  /// Completes once the session is unlocked; immediately if it already is.
  Future<void> untilUnlocked() async {
    while (_locked && !_closed) {
      await _unlocks.stream.isEmpty;
    }
  }

  /// The first launch, as one synchronous admission: the check that the
  /// session is unlocked, [start] and the marking of the engines as started
  /// happen with no await between them, so a lock cannot fall in the middle.
  /// Returns false, having started nothing, if the session is locked.
  bool admitStart(void Function() start) {
    if (_locked || _closed) return false;
    start();
    markStarted();
    return true;
  }

  /// The engines have been started by the first launch: later locks stop them.
  void markStarted() {
    for (final slot in _slots) {
      if (!slot.failed) slot.running = true;
    }
  }

  /// Revokes every running engine now. Idempotent.
  void lock() {
    if (_closed) return;
    _token++;
    _locked = true;
    for (final slot in _slots) {
      if (!slot.running) continue;
      slot.running = false;
      slot.needsResume = true;
      slot.stopping = _stop(slot);
    }
  }

  /// Resumes each suspended engine once its stop is confirmed, if the session
  /// is still the one this call opened.
  void unlock() {
    if (_closed) return;
    _token++;
    _locked = false;
    final token = _token;
    for (final slot in _slots) {
      if (slot.needsResume) unawaited(_resume(slot, token));
    }
    _unlocks.add(null);
  }

  Future<void> close() {
    _closed = true;
    _token++;
    return _unlocks.close();
  }

  Future<void> _stop(_Slot slot) async {
    try {
      await slot.engine.suspend();
    } catch (_) {
      slot.failed = true;
    } finally {
      slot.stopping = null;
    }
  }

  Future<void> _resume(_Slot slot, int token) async {
    final stopping = slot.stopping;
    if (stopping != null) await stopping;
    if (token != _token || _locked || slot.failed || !slot.needsResume) return;
    slot.needsResume = false;
    slot.running = true;
    slot.engine.resume();
  }
}

final class _Slot {
  final SessionEngine engine;
  Future<void>? stopping;
  var running = false;
  var needsResume = false;
  var failed = false;

  _Slot(this.engine);
}
