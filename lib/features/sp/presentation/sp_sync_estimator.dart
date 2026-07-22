import 'package:bb_mobile/generated/l10n/localization.dart';

/// Estimates remaining scan time from block-height progress, mirroring the
/// desktop wallet's `SyncEstimator`: keep an exponential moving average of
/// seconds-per-block and multiply by the blocks left. bwk emits no timing, so
/// wall time is measured between progress updates (the caller passes `now`).
///
/// Tuned for mobile responsiveness rather than silent's slow defaults
/// (alpha 0.01 / warmup 100): progress fires only every ~100 blocks, so a
/// 100-sample warmup would hide the ETA for ~10k blocks. A small warmup shows
/// an estimate within a few seconds; a higher alpha lets it track the current
/// rate instead of crawling.
class SpSyncEstimator {
  static const double _alpha = 0.1;
  static const int _warmup = 5;
  static const double _resetWindowSecs = 60;

  int? _lastHeight;
  int _remainingBlocks = 0;
  DateTime? _lastTime;
  double _emaSecsPerBlock = 0;
  int _samples = 0;

  void reset() {
    _lastHeight = null;
    _remainingBlocks = 0;
    _lastTime = null;
    _emaSecsPerBlock = 0;
    _samples = 0;
  }

  void update(int current, int end, DateTime now) {
    final lastHeight = _lastHeight;
    final lastTime = _lastTime;
    if (lastHeight != null && lastTime != null) {
      final blocksDone = current - lastHeight;
      if (blocksDone <= 0) return;
      final elapsed = now.difference(lastTime).inMicroseconds / 1e6;
      // A long gap means a pause or the receive->spend phase jump; rebase the
      // window without polluting the rate.
      if (elapsed > _resetWindowSecs) {
        _lastHeight = current;
        _remainingBlocks = end - current;
        _lastTime = now;
        return;
      }
      final rate = elapsed / blocksDone;
      _emaSecsPerBlock = _samples > 0
          ? _alpha * rate + (1 - _alpha) * _emaSecsPerBlock
          : rate;
      _samples++;
    }
    _lastHeight = current;
    _remainingBlocks = end - current;
    _lastTime = now;
  }

  /// Estimated seconds remaining, or null until enough samples are collected.
  int? estimateSecs() {
    if (_samples < _warmup) return null;
    return (_remainingBlocks * _emaSecsPerBlock).round();
  }
}

/// Compact human duration: "Xh Ym" / "Xm Ys" / "Xs".
String formatDuration(AppLocalizations loc, int secs) {
  final s = secs < 0 ? 0 : secs;
  final hours = s ~/ 3600;
  final mins = (s % 3600) ~/ 60;
  final rem = s % 60;
  if (hours > 0) return loc.spDurationHoursMinutes('$hours', '$mins');
  if (mins > 0) return loc.spDurationMinutesSeconds('$mins', '$rem');
  return loc.spDurationSeconds('$rem');
}
