/// Thrown when the platform hardware key backing a secret has been permanently
/// invalidated — e.g. the Android Keystore key was deleted after a biometric
/// re-enrollment or lock-screen change, or an iOS/macOS Keychain key was lost
/// after a device restore without key material.
///
/// The stored ciphertext exists but is unreadable forever.
///
/// Distinct from [KeychainLockedException] (transient, retryable) and
/// [SecretNotFoundException] (the key was never stored). This is permanent for
/// the HARDWARE copy.
///
/// Recovery is NOT a blanket `purge()` — during the dual period an intact FSS
/// copy of the SAME seed may still exist, and `purge()` deletes seed keys from
/// BOTH backends (`DualReadStore.purge`), destroying that recoverable copy. The
/// correct policy is: read via `DualReadStore` (which surfaces this rather than
/// masking it), and if the seed still exists in FSS the app can keep using it;
/// only when NO copy is readable does the app fall back to re-entry from the
/// user's own backup. Trash the single invalidated HARDWARE key (not a global
/// purge) if it must be cleared.
class HardwareKeyInvalidatedException implements Exception {
  const HardwareKeyInvalidatedException({this.key});

  /// The logical key whose hardware backing is gone, for diagnostics. Never a
  /// secret — a `seed_<fingerprint>` style name only.
  final String? key;

  @override
  String toString() => 'HardwareKeyInvalidatedException(key: $key)';
}
