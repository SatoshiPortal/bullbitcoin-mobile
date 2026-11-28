import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Process-local debug harness. No identifiers, balances, or secrets leave it.
final class BalanceStartupProbe {
  static const enabled =
      kDebugMode && bool.fromEnvironment('BULL_BALANCE_STARTUP_HARNESS');
  static Completer<void>? _held = bool.fromEnvironment('BULL_BALANCE_HOLD')
      ? Completer<void>()
      : null;
  static final _counts = <String, int>{};
  static bool _registered = false;

  BalanceStartupProbe() {
    if (_registered) return;
    _registered = true;
    developer.registerExtension('ext.bull.balanceStartup', (_, params) async {
      switch (params['action']) {
        case 'hold':
          _held ??= Completer<void>();
        case 'release':
          release();
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode({..._counts, 'held': _held != null}),
      );
    });
  }

  void arm() => _increment('armed');
  void initialized(bool ok) => _increment(ok ? 'initialized' : 'initRefused');
  void invalidate() => _increment('invalidations');
  void attempt() => _increment('attempted');
  void completed(bool ok, {required bool liquid}) {
    _increment(ok ? 'retained' : 'refused');
    if (ok) _increment(liquid ? 'liquidRetained' : 'bitcoinRetained');
  }

  Future<void> beforeDemand() async {
    if (_held case final held?) {
      _increment('blocked');
      await held.future;
    }
  }

  void release() {
    final held = _held;
    _held = null;
    held?.complete();
  }

  void _increment(String key) =>
      _counts.update(key, (value) => value + 1, ifAbsent: () => 1);
}
