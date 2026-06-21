import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The closed family of recoverable failures the `secrets` package returns in
/// `Result.Err`. Self-contained (the codebase has no shared `CoreFailure`): each
/// variant extends the bare [Failure] base directly.
///
/// Named `*Failure`, never `*Error` — `Error` is reserved for `dart:core`
/// programmer bugs that crash to Sentry. These are *values*, returned never
/// thrown across the public API. Translation happens app-side (the package
/// stays pure / l10n-free); see SECRETS_API_CONTRACTS §14.
///
/// `logMessage` is for logs/Sentry ONLY and is sanitized at the boundary (see
/// [sanitizeLog]) so it can never echo secret input into a sink.
@immutable
sealed class SecretsFailure extends Failure {
  const SecretsFailure([super.logMessage]);
}

/// The seed for [fingerprint] is not in storage. **Distinct from
/// [KeychainLockedFailure]** — never collapse the two (see that class).
final class SeedNotFoundFailure extends SecretsFailure {
  const SeedNotFoundFailure(this.fingerprint, [super.logMessage]);
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

/// Importing a seed whose [fingerprint] already exists (collision-safe handle).
final class DuplicateSeedFailure extends SecretsFailure {
  const DuplicateSeedFailure(this.fingerprint, [super.logMessage]);
  final Fingerprint fingerprint;
}

/// A mnemonic-only action was attempted on a bytes-only seed.
final class NotAMnemonicSeedFailure extends SecretsFailure {
  const NotAMnemonicSeedFailure([super.logMessage]);
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

/// Catch-all for an unexpected foreign exception at the boundary.
final class SecretsUnexpectedFailure extends SecretsFailure {
  const SecretsUnexpectedFailure([super.logMessage]);
}
