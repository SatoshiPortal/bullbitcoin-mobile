import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// How long the app may stay in the background before it locks (D93). Azad did
/// not fix this value; 60 s is the default and the pull request flags it.
const accessBackgroundLockDelay = Duration(seconds: 60);

/// Holds the automatic lock off for a flow that leaves the app on purpose
/// (scanner, file picker, Google sign-in, the OS biometric prompt).
final class LockSuspension {
  final void Function(LockSuspension) _release;
  final String reason;
  var _released = false;

  LockSuspension._(this.reason, this._release);

  /// Idempotent. Releasing never locks retroactively.
  void release() {
    if (_released) return;
    _released = true;
    _release(this);
  }
}

/// When to lock after the app left the foreground. Pure: the clock and the
/// timer are injected, and the lock itself is the host's callback.
///
/// `inactive` alone never starts the delay: permission prompts, the scanner and
/// the biometric sheet pass through it. The delay runs from `hidden`/`paused`.
/// A timer does not run while the OS suspends the process, so the elapsed time
/// is also read from the clock when the app returns.
final class AccessLockPolicy {
  final Future<void> Function() _lock;
  final Duration delay;
  final DateTime Function() _now;
  final Timer Function(Duration, void Function()) _timer;
  final _suspensions = <LockSuspension>{};
  Timer? _pending;
  DateTime? _backgroundedAt;
  bool _lockedInBackground = false;

  AccessLockPolicy({
    required Future<void> Function() onLock,
    this.delay = accessBackgroundLockDelay,
    DateTime Function()? now,
    Timer Function(Duration, void Function())? timer,
  }) : _lock = onLock,
       _now = now ?? DateTime.now,
       _timer = timer ?? Timer.new;

  bool get isSuspended => _suspensions.isNotEmpty;

  LockSuspension suspendAutoLock(String reason) {
    final suspension = LockSuspension._(reason, _suspensions.remove);
    _suspensions.add(suspension);
    return suspension;
  }

  void onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_backgroundedAt != null) return;
        _backgroundedAt = _now();
        _pending?.cancel();
        _pending = _timer(delay, _fire);
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        final alreadyLocked = _lockedInBackground;
        _clear();
        if (!alreadyLocked &&
            since != null &&
            _now().difference(since) >= delay) {
          _fireNow();
        }
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void dispose() => _clear();

  void _clear() {
    _pending?.cancel();
    _pending = null;
    _backgroundedAt = null;
    _lockedInBackground = false;
  }

  void _fire() {
    _pending = null;
    if (!isSuspended) _lockedInBackground = true;
    _fireNow();
  }

  void _fireNow() {
    if (isSuspended) return;
    unawaited(_lock());
  }
}
