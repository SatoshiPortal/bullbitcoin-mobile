import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';

/// Encrypted-vault encryption/restore. The plaintext (the seed) never leaves
/// the package.
///
/// [encryptVault] takes the [VaultKey] as an INPUT and returns ONLY the
/// ciphertext — it never mints and hands back a key beside the ciphertext.
/// Co-returning both from one call would collapse recoverbull's two-location
/// model (key and ciphertext held separately) into a single caller-held
/// plaintext, letting any caller decrypt the seed offline. The caller obtains
/// the key from a SEPARATE, deliberate step (e.g. the key server, or
/// `Secret.bip85RecoverbullKey`) and is responsible for storing it apart from
/// the ciphertext. [restoreVault] decrypts internally, stores the seed(s), and
/// returns only their fingerprints.
abstract interface class BackupVaultPort {
  @useResult
  Future<Result<EncryptedVault, SecretsFailure>> encryptVault({
    required Fingerprint fingerprint,
    required VaultKey vaultKey,
  });

  @useResult
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required VaultKey vaultKey,
  });
}
