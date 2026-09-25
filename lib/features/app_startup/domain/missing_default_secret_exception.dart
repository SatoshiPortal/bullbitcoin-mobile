/// Thrown at startup when a default wallet's metadata exists but its seed does
/// not — the keystore was read in full, through the retry loop, and had
/// nothing under that fingerprint.
///
/// The cohort this exists for: Android installs from 6.5.2 whose secrets lived
/// in Jetpack Security's EncryptedSharedPreferences, read through the
/// `flutter_secure_storage` 9 plugin. That plugin has been dropped and there
/// is no fallback, so those entries are simply not there any more. The
/// wallet metadata in SQLite is, which is why the app can tell the user
/// precisely what happened instead of showing an empty wallet list.
///
/// **Never a locked keystore.** That one is [KeychainLockedException] and is
/// transient: the app waits for the device to be unlocked and retries. Mixing
/// the two would offer a restore flow to a user whose seed is intact —
/// see `packages/secrets/README.md`, § Absence.
class MissingDefaultSecretException implements Exception {
  /// The wallet whose seed is gone. A fingerprint, never material.
  final String masterFingerprint;

  const MissingDefaultSecretException(this.masterFingerprint);

  @override
  String toString() =>
      'MissingDefaultSecretException: no secret for $masterFingerprint';
}
