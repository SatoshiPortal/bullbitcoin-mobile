/// Whether Android lets the app run in the background, implemented by the
/// app shell, which owns the platform channel. Battery optimization,
/// enforced hard by some vendors (Samsung), keeps periodic tasks from running
/// at all until the user allows unrestricted battery use.
abstract interface class BackgroundActivityGateway {
  /// Null where it does not apply (iOS, desktop) or cannot be read.
  Future<bool?> isUnrestricted();

  /// Opens the app's system settings, whose battery page holds the choice.
  Future<bool> openSettings();
}
