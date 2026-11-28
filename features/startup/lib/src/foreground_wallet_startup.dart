import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

import 'foreground_balance_startup.dart';
import 'session_engines.dart';

/// Activates foreground consumers once the admitted wallet runtime is ready,
/// and suspends them with the session: a lock stops every engine that signs or
/// reveals, and an unlock resumes each once, after its stop is confirmed.
final class ForegroundWalletStartup {
  final Future<Result<void, SyncFailure>> Function() _initialize;
  final ForegroundBalanceStartup? _balances;
  final void Function() _startWatchers;
  final PayjoinLifecycle Function()? _payjoin;
  final SessionEngines _engines;
  Future<void>? _startup;
  bool _ready = false;
  Future<void>? _disposing;

  ForegroundWalletStartup({
    required this._initialize,
    required this._startWatchers,
    this._balances,
    this._payjoin,
    SessionEngines? engines,
  }) : _engines = engines ?? SessionEngines(const []);

  Future<void> start() {
    if (_disposing case final disposing?) return disposing;
    if (_startup case final started?) return started;
    _balances?.admitUnlock();
    return _startup = _start();
  }

  Future<void> _start() async {
    final initialized = await _initialize();
    // A lock during initialization, or between the unlock and this
    // continuation, starts nothing: wait for the next unlock and try again.
    while (true) {
      await _engines.untilUnlocked();
      if (_disposing != null) return;
      if (_engines.admitStart(_startWatchers)) break;
    }
    _ready = true;
    _balances?.initialized(initialized);
    resumePayjoins();
  }

  /// True on every lock, false on every unlock.
  void onLockChanged(bool locked) {
    if (locked) {
      _balances?.revokeUnlock();
      _engines.lock();
    } else {
      _engines.unlock();
    }
  }

  /// The warm PIN route may return to any URI. An unlocked state emission
  /// by itself is not this authentication continuation.
  void confirmUnlock() => _balances?.admitUnlock();

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> _dispose() async {
    final drained = _balances?.dispose();
    await _engines.close();
    await drained;
  }

  /// Foreground recovery; a locked session resumes nothing.
  void resumePayjoins() {
    if (_payjoin case final payjoin?
        when _ready && _disposing == null && !_engines.isLocked) {
      unawaited(payjoin().resume());
    }
  }
}
