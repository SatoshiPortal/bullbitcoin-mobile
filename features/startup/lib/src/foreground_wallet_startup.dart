import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';

import 'session_engines.dart';

/// Activates foreground consumers once the admitted wallet runtime is ready,
/// and suspends them with the session: a lock stops every engine that signs or
/// reveals, and an unlock resumes each once, after its stop is confirmed.
final class ForegroundWalletStartup {
  final Future<void> Function() _initialize;
  final void Function() _startWatchers;
  final PayjoinLifecycle Function()? _payjoin;
  final SessionEngines _engines;
  Future<void>? _startup;
  bool _ready = false;

  ForegroundWalletStartup({
    required this._initialize,
    required this._startWatchers,
    this._payjoin,
    SessionEngines? engines,
  }) : _engines = engines ?? SessionEngines(const []);

  Future<void> start() => _startup ??= _start();

  Future<void> _start() async {
    await _initialize();
    // A lock during initialization starts nothing: wait for the unlock.
    await _engines.untilUnlocked();
    _startWatchers();
    _engines.markStarted();
    _ready = true;
    resumePayjoins();
  }

  /// True on every lock, false on every unlock.
  void onLockChanged(bool locked) =>
      locked ? _engines.lock() : _engines.unlock();

  /// Foreground recovery; a locked session resumes nothing.
  void resumePayjoins() {
    if (_payjoin case final payjoin? when _ready && !_engines.isLocked) {
      unawaited(payjoin().resume());
    }
  }
}
