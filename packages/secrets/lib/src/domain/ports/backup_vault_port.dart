import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../secrets_failure.dart';
import '../value_objects/backup.dart';

/// Encrypted-vault encryption/restore. The plaintext (the seed) never leaves
/// the package: [encryptVault] returns ciphertext + key; [restoreVault] decrypts
/// internally, stores the seed(s), and returns only their fingerprints.
abstract interface class BackupVaultPort {
  @useResult
  Future<Result<({EncryptedVault vault, BackupKey vaultKey}), SecretsFailure>>
      encryptVault({required Fingerprint seed});

  @useResult
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required BackupKey vaultKey,
  });
}
