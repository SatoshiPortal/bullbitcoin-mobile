import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The closed family of recoverable failures the `secrets` package returns in
/// `Result.Err`. Self-contained (the codebase has no shared `CoreFailure`): each
/// variant extends the bare [Failure] base directly.
///
/// Named `*Failure`, never `*Error`: these model *recoverable* outcomes as
/// returned *values* (never thrown across the public API). The package DOES
/// define a typed thrown `*Error` family (`SecretsError` in `secrets_error.dart`)
/// for precondition/programmer bugs — invalid value-object construction that
/// crashes to Sentry — which is a distinct axis from these RETURNED `*Failure`s.
/// Translation happens app-side (the package stays pure / l10n-free); see
/// SECRETS_API_CONTRACTS §14.
///
/// `logMessage` is for logs/Sentry ONLY. The package NEVER puts secret-bearing
/// text in it: at the `SecretGuard` boundary a foreign exception contributes
/// only its runtime *type* name, never its message, so a secret input can never
/// be echoed into a sink. Messages constructed in-package (fees, counts) carry
/// no secret material.
@immutable
sealed class SecretsFailure extends Failure {
  const SecretsFailure([super.logMessage]);
}

/// The secret for [fingerprint] is not in storage. **Distinct from
/// [KeychainLockedFailure]** — never collapse the two (see that class).
final class SecretNotFoundFailure extends SecretsFailure {
  const SecretNotFoundFailure(this.fingerprint, [super.logMessage]);
  final Fingerprint fingerprint;
}

/// The OS keychain/keystore is locked (e.g. iOS `errSecInteractionNotAllowed`
/// before first unlock). The seed almost certainly EXISTS — treating this as
/// "missing" can trigger destructive recovery, so it is a first-class variant
/// that callers must handle as a transient, self-healing state.
final class KeychainLockedFailure extends SecretsFailure {
  const KeychainLockedFailure([super.logMessage]);
}

/// An imported mnemonic failed checksum / word-list validation.
final class InvalidMnemonicFailure extends SecretsFailure {
  const InvalidMnemonicFailure([super.logMessage]);
}

/// Importing a secret whose [fingerprint] already exists (collision-safe handle).
final class DuplicateSecretFailure extends SecretsFailure {
  const DuplicateSecretFailure(this.fingerprint, [super.logMessage]);
  final Fingerprint fingerprint;
}

/// A mnemonic-only action was attempted on a bytes-only seed.
///
/// RESERVED / DORMANT: constructed nowhere today — it is the failure counterpart
/// of the dormant `SeedSecret` (there is no bytes-seed import path yet). It is
/// kept in this sealed family so handlers already account for it when that seam
/// lands; a `default`/`_` arm covers it until then. Do not treat its presence in
/// an exhaustive switch as evidence the case is currently reachable.
final class NotAMnemonicFailure extends SecretsFailure {
  const NotAMnemonicFailure([super.logMessage]);
}

/// Key derivation (BIP32/descriptor/BIP85) failed.
final class DerivationFailure extends SecretsFailure {
  const DerivationFailure([super.logMessage]);
}

/// Signing failed or was rejected by [SigningIntent] validation.
final class SigningFailure extends SecretsFailure {
  const SigningFailure([super.logMessage]);
}

/// Encrypted-vault encrypt/restore failure.
final class VaultFailure extends SecretsFailure {
  const VaultFailure([super.logMessage]);
}

/// The hardware key backing this secret was permanently invalidated by the OS
/// (Android Keystore key deleted after a biometric/lock-screen change; an
/// iOS/macOS key lost after a device restore without key material). The
/// ciphertext exists but is unreadable forever. NOT a transient lock
/// ([KeychainLockedFailure]) and NOT a missing import ([SecretNotFoundFailure]).
/// Recovery: purge, then have the user re-enter the secret from their backup.
final class KeyInvalidatedFailure extends SecretsFailure {
  const KeyInvalidatedFailure([super.logMessage]);
}

/// Catch-all for an unexpected foreign exception at the boundary.
final class SecretsUnexpectedFailure extends SecretsFailure {
  const SecretsUnexpectedFailure([super.logMessage]);
}
