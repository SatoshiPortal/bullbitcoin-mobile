import 'package:primitives/primitives.dart';

/// Import refused an existing secret without changing its stored value.
final class SecretAlreadyExistsFailure extends SecretFailure {
  final Fingerprint id;

  const SecretAlreadyExistsFailure(this.id) : super('secret already exists');
}

sealed class SecretFailure extends Failure {
  const SecretFailure([super.logMessage]);
}

final class SecretNotFoundFailure extends SecretFailure {
  const SecretNotFoundFailure([super.logMessage]);
}

/// The keystore is locked; the secret is intact. Callers must surface a
/// "unlock your device and retry" state, never a recovery flow.
final class KeystoreLockedFailure extends SecretFailure {
  const KeystoreLockedFailure([super.logMessage]);
}

final class FetchSecretFailure extends SecretFailure {
  const FetchSecretFailure([super.logMessage]);
}

final class StoreSecretFailure extends SecretFailure {
  const StoreSecretFailure([super.logMessage]);
}

final class TrashSecretFailure extends SecretFailure {
  const TrashSecretFailure([super.logMessage]);
}

/// The database key stored for a module is present but unusable, and was
/// deliberately **not** replaced.
///
/// Its own variant because the remedy is not the caller's usual one:
/// there is no retry that helps and no regeneration that is safe — a new
/// key would not open the database the old one encrypted. The only real
/// remedy is discarding that database together with its key, which only
/// the module owning the database can decide.
final class DatabaseKeyCorruptFailure extends SecretFailure {
  const DatabaseKeyCorruptFailure([super.logMessage]);
}

/// The operation needs BIP39 words and the secret has none.
final class MnemonicRequiredFailure extends SecretFailure {
  const MnemonicRequiredFailure([super.logMessage]);
}

/// The requested network exists in `primitives` but the underlying
/// library cannot express it. Currently only Liquid regtest: lwk's
/// `LiquidNetwork` has mainnet and testnet only, and substituting
/// testnet would return a descriptor whose addresses do not belong to
/// the chain the caller named.
final class UnsupportedNetworkFailure extends SecretFailure {
  const UnsupportedNetworkFailure([super.logMessage]);
}

/// The words given are not a BIP39 mnemonic: an unknown word, a bad
/// checksum or an undefined count. The message names the kind of
/// problem, never the word.
final class InvalidMnemonicFailure extends SecretFailure {
  const InvalidMnemonicFailure([super.logMessage]);
}

/// The vault could not be opened: the file is not a RecoverBull vault,
/// the key does not open it, or its plaintext carries no mnemonic.
/// Nothing was stored. Distinct from [StoreSecretFailure] so a wrong
/// key can be told apart from a keystore that refused a write.
final class InvalidVaultFailure extends SecretFailure {
  const InvalidVaultFailure([super.logMessage]);
}

/// The stored value does not derive to the fingerprint it is filed under, so it was not served.
///
/// Distinct from an unreadable or absent entry: the stored value is kept, and the caller must resolve which wallet it belongs to.
final class FingerprintMismatchFailure extends SecretFailure {
  const FingerprintMismatchFailure([super.logMessage]);
}

/// The secret was read but the engine refused the operation: a PSBT that does not parse, a descriptor it cannot build.
///
/// Kept apart from [FetchSecretFailure] so a bad input never reads as an unreadable seed.
final class UseSecretFailure extends SecretFailure {
  const UseSecretFailure([super.logMessage]);
}

/// What an unrecognised exception is allowed to say.
///
/// Libraries this package calls put their input in their error messages.
/// `bip39_mnemonic` is the clearest case — `MnemonicWordNotFoundException`
/// reads `Mnemonic word "<word>" does not exist`, and
/// `MnemonicInvalidChecksumException` names the last word — so an
/// exception raised on a user's mnemonic carries a word out with it.
/// `jsonDecode` quotes its source, and the source is the stored secret.
///
/// That matters because failures here do not stay put: they are logged,
/// which reaches crash reporting, and their text is folded into a
/// [Failure.logMessage], which callers print.
///
/// So the presumption is reversed for anything this package did not
/// raise itself: report the type, never the message. A type is enough to
/// tell a keystore failure from a parse failure, and it cannot carry a
/// secret.
///
/// Lives beside the failures rather than in the boundary that applies it
/// because both layers that report — the error boundary and the
/// datasource's own logging — need it, and both may depend on the
/// failure vocabulary.
String describeSafely(Object error) {
  // Raised by this package, with messages this package wrote.
  if (error is FormatException) return 'FormatException';
  return error.runtimeType.toString();
}
