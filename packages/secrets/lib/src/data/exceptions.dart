/// What the keystore layer can raise, and nothing else does.
///
/// Internal. None of these leaves the package: the error boundary in `public/` turns each into the `SecretFailure` a caller handles. They exist so that the boundary classifies by **type**, never by parsing a message — and so that the two failure modes the keystore has that matter to a caller stay apart from every other `Exception`.
///
/// Messages are this package's own fixed strings plus, at most, a storage key composed by this package. Never stored content: an envelope field is untrusted input on Linux and Windows, and a message that quoted one would carry it into a failure and a log.
library;

import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

/// The same secret is already stored; an import must create a new entry.
class SecretAlreadyExistsException implements Exception {
  final Fingerprint id;

  @internal
  const SecretAlreadyExistsException(this.id);
}

/// A module key is present but cannot be used, and must not be replaced.
///
/// Distinct from every other failure here because the remedy is the
/// opposite one: a corrupt *seed* entry is skipped, a corrupt module key
/// is refused and kept. Translated to `DatabaseKeyCorruptFailure` by the
/// error boundary, so a caller can tell "your database key is damaged"
/// from "the keystore refused a write" — and can offer the only real
/// remedy, which is discarding the database and its key together.
class ModuleKeyCorruptException implements Exception {
  final String message;
  @internal
  const ModuleKeyCorruptException(this.message);

  @override
  String toString() => 'ModuleKeyCorruptException: $message';
}

class KeystoreLockedException implements Exception {
  final String message;
  @internal
  const KeystoreLockedException(this.message);

  @override
  String toString() => 'KeystoreLockedException: $message';
}

/// A different secret is already stored under this fingerprint.
///
/// Two BIP32 fingerprints can collide; the first secret stored under one must not be replaced by the second. Translated to `StoreSecretFailure` by the error boundary — nothing was written.
class FingerprintConflictException implements Exception {
  final String message;
  @internal
  const FingerprintConflictException(this.message);

  @override
  String toString() => 'FingerprintConflictException: $message';
}

/// The value under a key derives to a different fingerprint than the key names.
///
/// Serving it would hand one wallet's keys under another wallet's fingerprint, so a read refuses. Translated to `FingerprintMismatchFailure`; the entry is left as it is.
class FingerprintMismatchException implements Exception {
  final String message;
  @internal
  const FingerprintMismatchException(this.message);

  @override
  String toString() => 'FingerprintMismatchException: $message';
}
