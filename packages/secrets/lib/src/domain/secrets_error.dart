import 'package:meta/meta.dart';

/// Thrown (never returned) precondition violations — invalid construction of a
/// value object. Programmer bugs that crash, unlike the RETURNED
/// [SecretsFailure].
///
/// Extends [ArgumentError] so existing `catch (ArgumentError)` /
/// `throwsArgumentError` keep working (`message`/`name` survive; the rejected
/// value is deliberately NOT passed, so no secret-ish input is retained on the
/// error object); sealed so the package's set is closed.
@immutable
sealed class SecretsError extends ArgumentError {
  SecretsError(super.message, [super.name]);
}

/// An [Xpub] was constructed from an invalid value (e.g. empty).
final class InvalidXpubError extends SecretsError {
  InvalidXpubError(super.message, [super.name]);
}

/// A descriptor (Bitcoin/Liquid) was constructed from an invalid value.
final class InvalidDescriptorError extends SecretsError {
  InvalidDescriptorError(super.message, [super.name]);
}

/// A `Psbt`/`SignedPsbt` was constructed from invalid/empty base64.
final class InvalidPsbtError extends SecretsError {
  InvalidPsbtError(super.message, [super.name]);
}

/// A `Bip85Path` was constructed from an invalid path string.
final class InvalidBip85PathError extends SecretsError {
  InvalidBip85PathError(super.message, [super.name]);
}

/// A `Bip85Application` was looked up by an unknown application number.
final class UnknownBip85ApplicationError extends SecretsError {
  UnknownBip85ApplicationError(super.message, [super.name]);
}

/// A `VaultKey` was constructed from too-short key material.
final class InvalidVaultKeyError extends SecretsError {
  InvalidVaultKeyError(super.message, [super.name]);
}

/// An `EncryptedVault` was constructed from an invalid/empty ciphertext.
final class InvalidEncryptedVaultError extends SecretsError {
  InvalidEncryptedVaultError(super.message, [super.name]);
}

/// An `ArkSecret` was constructed from bytes of the wrong length.
final class InvalidArkSecretError extends SecretsError {
  InvalidArkSecretError(super.message, [super.name]);
}

/// A `MnemonicLength` was requested for an unsupported word count.
final class UnsupportedMnemonicLengthError extends SecretsError {
  UnsupportedMnemonicLengthError(super.message, [super.name]);
}
