/// What the crypto adapters can raise on their own account.
///
/// Internal, like `data/exceptions.dart`: the error boundary turns each into a `SecretFailure`. Foreign exceptions — bdk, lwk, boltz, recoverbull — are not listed here; they are caught where they arise and either translated to one of these or reported by type alone, so no library's message travels.
///
/// Every message is one of this file's callers' fixed strings.
library;

/// Thrown when `LiquidNetwork.regtest` reaches lwk, which has no such
/// variant — here and in `LiquidSigner`. Translated to
/// `UnsupportedNetworkFailure` by the error boundary.
class UnsupportedLiquidNetwork implements Exception {
  final String message;
  const UnsupportedLiquidNetwork(this.message);

  @override
  String toString() => 'UnsupportedLiquidNetwork: $message';
}

/// Thrown by `RecoverBullBackup.open` for anything that is not a vault this
/// key opens. Translated to `InvalidVaultFailure` by the façade. The
/// message is always one of `RecoverBullBackup`'s own fixed strings, so it
/// can travel into a failure without a redaction step.
class InvalidVault implements Exception {
  final String message;
  const InvalidVault(this.message);

  @override
  String toString() => 'InvalidVault: $message';
}

/// lwk refused to sign. Carries nothing: lwk's own message is dropped on purpose. Reported by type as `SecretDerivationFailure`.
class LiquidSigningFailed implements Exception {
  const LiquidSigningFailed();
}
