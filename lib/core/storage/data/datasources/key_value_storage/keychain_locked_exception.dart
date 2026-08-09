import 'package:flutter/services.dart' show PlatformException;

/// Thrown by secure-storage datasources when the underlying OS keychain
/// refuses an operation because the device is in a state where keychain
/// items aren't currently readable.
///
/// On iOS this is `errSecInteractionNotAllowed` (OSStatus -25308),
/// returned by the Security framework when the device has not been
/// unlocked since boot AND the item's accessibility class requires
/// post-unlock access (BULL uses
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` for all keychain
/// items — see `lib/core/storage/storage_locator.dart`).
///
/// Callers decide whether this is fatal or recoverable:
///
/// - For *probes* and *optional* reads (e.g. exchange API key, WebSocket
///   reconnect): catch and treat as "value temporarily unavailable",
///   skip the work, let the user trigger it again post-unlock.
/// - For *load-bearing* reads (e.g. wallet seeds): DO NOT catch and
///   return null — that would conflate "seed missing" with "device
///   locked" and could trigger destructive recovery flows. Let the
///   exception bubble up to the UI, which can show a "device just
///   unlocked, please retry" prompt.
///
/// On writes (`saveValue` / `deleteValue`), this exception always
/// indicates a real failure: the caller MUST surface or rethrow,
/// because silently swallowing means data was not persisted.
///
/// Debug context (which operation, which key) is emitted as a
/// `log.warning` line at the datasource layer *before* this exception
/// is thrown, so the exception itself doesn't need to carry it.
class KeychainLockedException implements Exception {
  const KeychainLockedException();

  @override
  String toString() =>
      'KeychainLockedException: device not unlocked since boot';
}

/// iOS keychain `OSStatus` for `errSecInteractionNotAllowed`. Returned
/// by `SecItemCopyMatching` / `SecItemAdd` when the item's accessibility
/// class requires the device to be unlocked (or to have been unlocked
/// since boot) and the current state doesn't satisfy that.
const int errSecInteractionNotAllowed = -25308;

/// Whether [e] is the keychain telling us "not now, the device has not
/// been unlocked since boot" rather than "no such item" or a real
/// failure.
///
/// Belt-and-suspenders: across `flutter_secure_storage` releases the
/// OSStatus has historically appeared in `details` (current fork), in
/// `code` (older versions, as a string), or embedded in `message`.
/// Match all three so a future fork bump that shifts the field doesn't
/// silently regress this whole class of handling without a compile
/// error.
///
/// Shared by every caller that talks to the keychain — the fss9 and
/// fss10 datasource impls can't share their `_wrap` (the two plugins
/// expose distinct types) but this predicate only touches
/// `PlatformException`, which they do share, and duplicating a
/// security-critical constant is how one copy silently drifts.
bool isKeychainLocked(PlatformException e) =>
    e.details == errSecInteractionNotAllowed ||
    e.code == '$errSecInteractionNotAllowed' ||
    (e.message ?? '').contains('$errSecInteractionNotAllowed');
