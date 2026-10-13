import 'package:screen_privacy/src/screen_capture_protection.dart';

/// Adds screen-capture protection to a screen for as long as it is mounted.
///
/// Call [enableScreenPrivacy] when the screen appears (in `initState` or a
/// stored future) and [disableScreenPrivacy] once when it goes away (in
/// `dispose`). A screen that shows a secret draws it only once
/// [enableScreenPrivacy] has returned `true`.
mixin PrivacyScreen {
  bool _privacyAcquired = false;

  /// Whether the secret may be shown. Calling it again after `false` retries
  /// without counting the screen twice.
  Future<bool> enableScreenPrivacy() async {
    if (_privacyAcquired) return ScreenCaptureProtection.instance.resync();
    _privacyAcquired = true;
    return ScreenCaptureProtection.instance.acquire();
  }

  Future<void> disableScreenPrivacy() async {
    if (!_privacyAcquired) return;
    _privacyAcquired = false;
    await ScreenCaptureProtection.instance.release();
  }
}
