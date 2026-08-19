import 'package:bb_mobile/core/utils/logger.dart';
import 'package:no_screenshot/no_screenshot.dart';

/// Controls OS-level screen-capture blocking (Android `FLAG_SECURE`, iOS secure
/// overlay) via the `no_screenshot` plugin.
///
/// The flag is app-wide, not per-screen, so it must be reference counted: this
/// counts how many protected screens are mounted and only clears the flag once
/// the last one is gone. It also honours the user preference ([enabledByUser]).
/// A process-wide singleton, because the flag it manages is process-wide.
class ScreenCaptureProtection {
  ScreenCaptureProtection._();

  static final ScreenCaptureProtection instance = ScreenCaptureProtection._();

  final NoScreenshot _noScreenshot = NoScreenshot.instance;

  int _activeCount = 0;
  bool _enabledByUser = true;

  /// Whether the user wants sensitive screens protected from capture.
  ///
  /// Defaults to `true` so protection is on before settings have loaded and if
  /// the setting is ever unavailable — a fail-safe default for key material.
  bool get enabledByUser => _enabledByUser;

  set enabledByUser(bool value) {
    if (_enabledByUser == value) return;
    _enabledByUser = value;
    _sync();
  }

  /// Registers one more mounted protected screen.
  Future<void> acquire() async {
    _activeCount++;
    await _sync();
  }

  /// Unregisters one previously [acquire]d protected screen.
  Future<void> release() async {
    if (_activeCount > 0) _activeCount--;
    await _sync();
  }

  Future<void> _sync() async {
    final shouldProtect = _enabledByUser && _activeCount > 0;
    try {
      if (shouldProtect) {
        await _noScreenshot.screenshotOff();
      } else {
        await _noScreenshot.screenshotOn();
      }
    } catch (e, st) {
      // Callers fire-and-forget this, so a platform-channel failure would
      // otherwise vanish as an unhandled async error. On a secret screen a
      // silent failure means we may be showing the mnemonic without
      // FLAG_SECURE set, so make it loud rather than let it disappear.
      log.severe(
        message:
            'ScreenCaptureProtection: failed to '
            '${shouldProtect ? 'enable' : 'disable'} capture blocking',
        error: e,
        trace: st,
      );
    }
  }
}
