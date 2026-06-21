import 'package:flutter/services.dart';

/// Thrown by `FssSecretStore` when the OS keychain/keystore is locked.
///
/// This is the package-internal "foreign exception" for the locked condition;
/// the repository boundary converts it to `KeychainLockedFailure`. It is NEVER
/// converted to a not-found result — see `KeychainLockedFailure`.
class KeychainLockedException implements Exception {
  const KeychainLockedException([this.message]);
  final String? message;
  @override
  String toString() => 'KeychainLockedException(${message ?? ''})';
}

/// Best-effort detection of a locked-keychain platform error.
///
/// iOS returns `errSecInteractionNotAllowed` (-25308) before first unlock when
/// the item requires post-unlock access (BULL uses
/// `AfterFirstUnlockThisDeviceOnly`). Android surfaces a user-not-authenticated
/// / keystore error. We match on code + message rather than trust a single
/// platform's spelling.
bool isKeychainLockedError(Object error) {
  if (error is KeychainLockedException) return true;
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final msg = (error.message ?? '').toLowerCase();
    // Match ONLY signals that specifically mean "locked / not authenticated".
    // Deliberately NOT the bare substring 'keystore' — it appears in many
    // non-lock Android errors (corrupt/missing entry, decryption failure), and
    // misclassifying those as "locked" would hide a real loss behind an endless
    // "unlock and retry" (the inverse of the locked≠missing invariant).
    const needles = [
      '-25308',
      'interactionnotallowed',
      'interaction_not_allowed',
      'usernotauthenticated',
      'user not authenticated',
      'keychain is locked',
      'keystore is locked',
      'keystore not initialized',
    ];
    return needles.any((n) => code.contains(n) || msg.contains(n));
  }
  return false;
}
