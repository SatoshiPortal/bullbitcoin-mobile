import 'dart:async';

import 'package:bull_payjoin/bull_payjoin.dart';

/// Activates foreground consumers once the admitted wallet runtime is ready.
final class ForegroundWalletStartup {
  final Future<void> Function() _initialize;
  final void Function() _startWatchers;
  final PayjoinLifecycle Function()? _payjoin;
  Future<void>? _startup;
  bool _ready = false;

  ForegroundWalletStartup({
    required this._initialize,
    required this._startWatchers,
    this._payjoin,
  });

  Future<void> start() => _startup ??= _start();

  Future<void> _start() async {
    await _initialize();
    _startWatchers();
    _ready = true;
    resumePayjoins();
  }

  void resumePayjoins() {
    if (_payjoin case final payjoin? when _ready) {
      unawaited(payjoin().resume());
    }
  }
}
