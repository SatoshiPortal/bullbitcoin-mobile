import 'dart:typed_data';

import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as rb;
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/backup_vault_port.dart';
import 'package:secrets/src/domain/ports/secret_lifecycle_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/domain/value_objects/mnemonic_language.dart';

/// Wraps the `recoverbull` package directly (NOT the app-layer JSON wrappers).
/// The vault plaintext is the mnemonic's storage representation, encrypted with
/// a CALLER-SUPPLIED [VaultKey]; restore re-imports through [SecretLifecyclePort]
/// so the mnemonic never escapes. The key is taken as an input (never minted and
/// returned beside the ciphertext) so a single call can't hand a caller both the
/// ciphertext and its decryption key — see [BackupVaultPort].
class BackupVaultAdapter implements BackupVaultPort {
  BackupVaultAdapter({
    required SecretStorePort store,
    required SecretLifecyclePort repository,
  })  : _guard = SecretGuard(store),
        _repo = repository;

  final SecretGuard _guard;
  final SecretLifecyclePort _repo;

  @override
  Future<Result<EncryptedVault, SecretsFailure>> encryptVault({
    required Fingerprint fingerprint,
    required VaultKey vaultKey,
  }) =>
      _guard.read(fingerprint, (m) async {
        // The key is caller-supplied — the package encrypts with it and returns
        // ONLY the ciphertext, never the key. A `VaultKey.bytes` getter defends
        // its buffer with a copy, so read it once here.
        final backup = rb.RecoverBull.createBackup(
          secret: m.toStorageBytes(),
          backupKey: vaultKey.bytes,
        );
        return Ok(EncryptedVault(backup.toJson()));
      }, onError: VaultFailure.new);

  @override
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required VaultKey vaultKey,
  }) =>
      _guard.run(() async {
        final backup = rb.BullBackup.fromJson(vault.ciphertextJson);
        final plaintext = rb.RecoverBull.restoreBackup(
          backup: backup,
          backupKey: vaultKey.bytes,
        );
        final mnemonic = Mnemonic.fromStorageBytes(Uint8List.fromList(plaintext));

        final imported = await _repo.importMnemonic(
          words: mnemonic.words,
          passphrase: mnemonic.passphrase,
          language: MnemonicLanguage.fromName(mnemonic.language.name) ??
              MnemonicLanguage.english,
        );

        return switch (imported) {
          Ok(:final value) => Ok([value]),
          // A duplicate on restore is benign — the seed is already present.
          Err(failure: DuplicateSecretFailure(:final fingerprint)) =>
            Ok([fingerprint]),
          Err(:final failure) => Err(failure),
        };
      }, onError: VaultFailure.new);
}
