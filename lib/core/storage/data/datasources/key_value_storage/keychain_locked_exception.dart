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
class KeychainLockedException implements Exception {
  /// The key the operation was attempting (helps debugging; never logged
  /// with PII because BULL keychain keys are constants like
  /// `exchange_api_key`, not user data).
  final String key;

  /// The operation that hit the lock state — `read`, `write`, `delete`,
  /// `contains`, `readAll`, `deleteAll`.
  final String operation;

  KeychainLockedException({required this.key, required this.operation});

  @override
  String toString() =>
      'KeychainLockedException: keychain locked '
      '(errSecInteractionNotAllowed / -25308) during $operation '
      'of "$key". Device has not been unlocked since boot.';
}
