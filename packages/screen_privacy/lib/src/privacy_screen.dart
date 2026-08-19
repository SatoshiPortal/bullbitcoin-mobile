import 'package:screen_privacy/src/screen_capture_protection.dart';

/// Adds screen-capture protection to a screen for as long as it is mounted.
///
/// Call [enableScreenPrivacy] once when the screen appears (in `initState` or a
/// stored future) and [disableScreenPrivacy] once when it goes away (in
/// `dispose`).
mixin PrivacyScreen {
  bool _privacyAcquired = false;

  Future<void> enableScreenPrivacy() async {
    if (_privacyAcquired) return;
    _privacyAcquired = true;
    await ScreenCaptureProtection.instance.acquire();
  }

  Future<void> disableScreenPrivacy() async {
    if (!_privacyAcquired) return;
    _privacyAcquired = false;
    await ScreenCaptureProtection.instance.release();
  }
}
