/// Thrown when the platform hardware key backing a secret has been permanently
/// invalidated — e.g. the Android Keystore key was deleted after a biometric
/// re-enrollment or lock-screen change, or an iOS/macOS Keychain key was lost
/// after a device restore without key material.
///
/// The stored ciphertext exists but is unreadable forever.
///
/// Distinct from [KeychainLockedException] (transient, retryable) and
/// [SecretNotFoundException] (the key was never stored). This is permanent:
/// recovery is `purge()` + the user re-entering the secret from their backup.
class HardwareKeyInvalidatedException implements Exception {
  const HardwareKeyInvalidatedException({this.key});

  /// The logical key whose hardware backing is gone, for diagnostics. Never a
  /// secret — a `seed_<fingerprint>` style name only.
  final String? key;

  @override
  String toString() => 'HardwareKeyInvalidatedException(key: $key)';
}
