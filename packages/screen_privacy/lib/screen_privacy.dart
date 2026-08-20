/// Screen-capture protection for sensitive screens (recovery phrase, seed
/// views): blocks screenshots and screen recording via the OS secure flag
/// (Android `FLAG_SECURE`, iOS secure overlay).
///
/// A screen opts in with the [PrivacyScreen] mixin; the process-wide
/// [ScreenCaptureProtection] controller reference-counts protected screens and
/// gates the flag on the user's preference.
library;

export 'src/privacy_screen.dart';
export 'src/screen_capture_protection.dart';
