/// Backups of a secret, one file per format.
///
/// A backup here is the *whole* operation — assemble the plaintext, seal
/// it, derive the key that opens it — because every half of it holds
/// material: a caller that could assemble the plaintext would already
/// hold the words, and one that could derive the key would hold an xprv.
/// What leaves is ciphertext and the key, never the words, and the two
/// are meant to be stored apart.
///
/// Reached through [Backup], a namespace: `Backup.recoverbull.seal(…)`.
/// Static like the derivers: a format is a pure function of material,
/// with nothing to inject and its key derivation pinned by
/// `test/derivation_vectors_test.dart`.
///
/// **Adding a format:** `<format>_backup.dart` here, a `const` class whose
/// `seal` takes the words and returns ciphertext, whose `open` returns
/// the words separately from the caller's own fields, and whose failures
/// are its own fixed strings — exported below, and a `static const` on
/// [Backup]. Then a method on `Secret` beside `backupVault`.
library;

import 'package:secrets/src/crypto/backups/recoverbull_backup.dart';

export 'recoverbull_backup.dart' show RecoverBullBackup;

/// The backup formats, by name. Not instantiable; a namespace.
abstract final class Backup {
  /// The RecoverBull vault: BIP85 key at `1608'/0'/<random>'`, JSON
  /// plaintext with the words under `mnemonic`, path carried in the file.
  static const recoverbull = RecoverBullBackup();
}
