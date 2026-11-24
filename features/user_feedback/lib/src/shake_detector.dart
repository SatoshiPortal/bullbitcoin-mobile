import 'dart:math' as math;

/// Turns accelerometer samples (gravity excluded, in m/s²) into shakes.
///
/// A shake is [hitsNeeded] samples stronger than [threshold] within [window].
/// After a shake, samples are ignored for [cooldown] so one shake fires once.
final class ShakeDetector {
  final double threshold;
  final int hitsNeeded;
  final Duration window;
  final Duration cooldown;
  final List<DateTime> _hits = [];
  DateTime? _lastShake;

  ShakeDetector({
    this.threshold = 14,
    this.hitsNeeded = 3,
    this.window = const Duration(milliseconds: 800),
    this.cooldown = const Duration(seconds: 3),
  });

  /// Records one sample taken [at], and returns whether it completes a shake.
  bool add({
    required double x,
    required double y,
    required double z,
    required DateTime at,
  }) {
    final lastShake = _lastShake;
    if (lastShake != null && at.difference(lastShake) < cooldown) return false;
    if (math.sqrt(x * x + y * y + z * z) < threshold) return false;

    _hits
      ..add(at)
      ..removeWhere((hit) => at.difference(hit) > window);
    if (_hits.length < hitsNeeded) return false;

    _hits.clear();
    _lastShake = at;
    return true;
  }
}
