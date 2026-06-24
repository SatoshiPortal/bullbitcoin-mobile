/// Thrown by `Mnemonic.fromStorageBytes` when a stored secret blob cannot be
/// decoded into any recognized on-disk format. The repository/port boundary
/// (`SecretGuard`) maps it to an `InvalidMnemonicFailure` — malformed storage
/// is a recoverable boundary condition, NOT a `dart:core` `Error` that crashes.
///
/// It is an `Exception` (not an `Error`) precisely so `SecretGuard` can catch it
/// and convert it to a `*Failure` rather than let it escape.
class MalformedSecretException implements Exception {
  const MalformedSecretException(this.message);
  final String message;
  @override
  String toString() => 'MalformedSecretException($message)';
}
