class UnlockCooldown {
  final Stopwatch _stopwatch;

  int _durationSeconds = 0;
  bool _initialized = false;

  UnlockCooldown({Stopwatch? stopwatch})
    : _stopwatch = stopwatch ?? Stopwatch();

  int get remainingSeconds {
    if (!_initialized || _durationSeconds == 0) return 0;
    final remainingMilliseconds =
        _durationSeconds * 1000 - _stopwatch.elapsedMilliseconds;
    return remainingMilliseconds <= 0
        ? 0
        : (remainingMilliseconds + 999) ~/ 1000;
  }

  void restore({
    required int fallbackSeconds,
    required DateTime? lockedUntil,
    required DateTime now,
  }) {
    if (_initialized) return;

    final wallClockRemaining = lockedUntil == null
        ? 0
        : _remainingSeconds(lockedUntil, now);
    final restored = switch ((fallbackSeconds, wallClockRemaining)) {
      (0, final wall) => wall,
      (final fallback, final wall) when wall > 0 =>
        wall.clamp(1, fallback).toInt(),
      (final fallback, _) => fallback,
    };
    start(restored);
  }

  void start(int seconds) {
    _durationSeconds = seconds;
    _initialized = true;
    _stopwatch
      ..reset()
      ..start();
  }

  void clear() {
    _durationSeconds = 0;
    _initialized = true;
    _stopwatch
      ..stop()
      ..reset();
  }

  static int _remainingSeconds(DateTime lockedUntil, DateTime now) {
    final millis = lockedUntil.difference(now).inMilliseconds;
    return millis <= 0 ? 0 : (millis + 999) ~/ 1000;
  }
}
