import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/encrypted_vault.dart';
import '../entities/vault_backup.dart';
import '../entities/vault_context.dart';
import '../recoverbull_failure.dart';

abstract interface class VaultRepository {
  @useResult
  Result<EncryptedVault, RecoverBullFailure> parse(String document);

  String encode(EncryptedVault vault);

  @useResult
  Future<Result<VaultBackup, RecoverBullFailure>> create(VaultContext context);

  /// Stateless inspection: never imports a temporary secret.
  @useResult
  Future<Result<Fingerprint, RecoverBullFailure>> fingerprint(
    EncryptedVault vault,
    VaultKey key, {
    String passphrase = '',
  });

  /// Imports inside Secrets and returns only the stored public identity.
  @useResult
  Future<Result<Fingerprint, RecoverBullFailure>> restore(
    EncryptedVault vault,
    VaultKey key, {
    String passphrase = '',
    bool allowUnverified = false,
  });
}
