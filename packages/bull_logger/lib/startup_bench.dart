import 'package:flutter/foundation.dart';

/// Local startup instrumentation. Fixed labels only; never add user data.
final class StartupBench {
  static final Stopwatch _watch = Stopwatch();
  static final Set<String> _once = <String>{};
  static int _previousUs = 0;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    _watch.start();
    mark('app_start');
  }

  /// Restores the state of a process that never called [start], so tests do
  /// not observe each other's stopwatch, one-shot labels or previous mark.
  @visibleForTesting
  static void reset() {
    _watch
      ..stop()
      ..reset();
    _once.clear();
    _previousUs = 0;
    _started = false;
  }

  static void markOnce(String phase) {
    if (!_once.add(phase)) return;
    mark(phase);
  }

  static void mark(String phase) {
    if (kReleaseMode) return;
    if (!_started) start();
    final elapsedUs = _watch.elapsedMicroseconds;
    final deltaUs = elapsedUs - _previousUs;
    _previousUs = elapsedUs;
    debugPrint(
      'BULL_STARTUP_BENCH v=1 ph=$phase t_us=$elapsedUs d_us=$deltaUs',
    );
  }
}
