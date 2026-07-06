import 'package:flutter/services.dart';

/// Thrown by `FssSecretStoreAdapter` when the OS keychain/keystore is locked.
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
/// / keystore error. We match on code + details + message rather than trust a
/// single platform's spelling.
///
/// CRITICAL: the OSStatus location varies BY FORK. The pinned
/// `SatoshiPortal/flutter_secure_storage` fork delivers -25308 in
/// `PlatformException.details` (int), older versions put it in `code` (string),
/// and it can also be embedded in `message`. This mirrors the app's own
/// production handler (`_isLocked` in `secure_storage_data_source_impl.dart`),
/// which checks all three — inspecting only `code`+`message` (as this once did)
/// leaves a real lock on the CURRENT fork unrecognized, so it is mis-handled as
/// a transient/unexpected error and bypasses every locked-keychain carve-out
/// (defer/retry, store→verify readback). See H2.
bool isKeychainLockedError(Object error) {
  if (error is KeychainLockedException) return true;
  if (error is! PlatformException) return false;

  // Normalize each side: lowercase and strip every non-alphanumeric char, so
  // separator variants collapse to one form — `user_not_authenticated`,
  // `user not authenticated`, and `UserNotAuthenticated` all become
  // `usernotauthenticated`. Otherwise a locked device whose platform spelling
  // differs only in punctuation is left raw and later mis-classified.
  final code = _normalize(error.code);
  final msg = _normalize(error.message ?? '');
  // `details` is the field the pinned fork uses for the OSStatus; it may be an
  // int (-25308) or a String — `toString()` covers both before normalizing.
  final details = _normalize(error.details?.toString() ?? '');

  // The iOS errSecInteractionNotAllowed status (-25308 → '25308' normalized) is
  // a bare number that could appear incidentally in an UNRELATED error's
  // free-text message (a byte count, an offset). So it is matched only as the
  // whole error CODE or whole DETAILS value (exact), plus — to mirror the
  // production handler — the SIGNED literal `-25308` anywhere in the raw
  // message (the leading sign makes an incidental collision unlikely).
  if (code == '25308' || details == '25308') return true;
  if ((error.message ?? '').contains('-25308')) return true;

  // Match ONLY signals that specifically mean "locked / not authenticated".
  // Deliberately NOT the bare substring 'keystore' — it appears in many
  // non-lock Android errors (corrupt/missing entry, decryption failure), and
  // misclassifying those as "locked" would hide a real loss behind an endless
  // "unlock and retry" (the inverse of the locked≠missing invariant). Needles
  // are stored separator-free to match the normalized input, and are scanned
  // across code, message AND details (the fork can surface them in details).
  const needles = [
    'interactionnotallowed',
    'usernotauthenticated',
    'keyisnotauthenticated',
    'keychainislocked',
    'keystoreislocked',
    'keystorenotinitialized',
    'keystorelocked',
    'keyusernotauthenticated',
  ];
  return needles
      .any((n) => code.contains(n) || msg.contains(n) || details.contains(n));
}

/// Lowercase + strip every non-`[a-z0-9]` char, so punctuation/casing/spelling
/// variants of the same locked signal collapse to one comparable form.
String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
