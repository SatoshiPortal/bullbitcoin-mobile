import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/services.dart';
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
  bool _channelFailed = false;

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
  ///
  /// Returns whether the screen may show its secret: capture blocking is in
  /// effect, or the user turned it off. `false` means the plugin refused or
  /// failed, and the secret must stay hidden.
  Future<bool> acquire() async {
    _activeCount++;
    return _sync();
  }

  /// Applies the current state again — the retry for an [acquire] that
  /// returned `false`. Same verdict as [acquire].
  Future<bool> resync() => _sync();

  /// Unregisters one previously [acquire]d protected screen.
  Future<void> release() async {
    if (_activeCount > 0) _activeCount--;
    await _sync();
  }

  Future<bool> _sync() async {
    final shouldProtect = _enabledByUser && _activeCount > 0;
    try {
      if (shouldProtect) {
        // `false` is the plugin saying the flag is not set (no window yet on
        // iOS, a native failure on Android): not a secret screen's green light.
        final protected = await _noScreenshot.screenshotOff();
        if (protected) _channelFailed = false;
        return protected;
      }
      await _noScreenshot.screenshotOn();
      _channelFailed = false;
      return true;
    } catch (e, st) {
      if (!_channelFailed &&
          e is! PlatformException &&
          e is! MissingPluginException) {
        log.severe(
          message: 'Privacy channel failed reason=unexpected',
          error: 'platform',
          trace: st,
        );
      } else if (!_channelFailed && !shouldProtect) {
        log.warning('Privacy release failed reason=platform');
      }
      _channelFailed = true;
      return !shouldProtect;
    }
  }
}
