import 'dart:typed_data';

import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as rb;
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/bip85_derivation.dart';
import 'package:secrets/src/data/datasources/fss_secret_store.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/data/datasources/secret_not_found_exception.dart';
import 'package:secrets/src/data/models/seed_secret.dart';
import 'package:secrets/src/domain/backup_vault_port.dart';
import 'package:secrets/src/domain/seed_repository.dart';
import 'package:secrets/src/domain/log_sanitizer.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';
import 'package:secrets/src/storage/secret_store.dart';

/// Wraps the `recoverbull` package directly (NOT the app-layer JSON wrappers).
/// The vault plaintext is the seed's storage representation, encrypted with a
/// fresh BIP85-derived backup key; restore re-imports through [SeedRepositoryImpl]
/// so the mnemonic never escapes.
class BackupVaultPortImpl implements BackupVaultPort {
  BackupVaultPortImpl({
    required SecretStore store,
    required SeedRepository repository,
  })  : _store = store,
        _repo = repository;

  final SecretStore _store;
  final SeedRepository _repo;

  String _key(Fingerprint fp) => SecretStoreKeys.seedKey(fp.hex);

  @override
  Future<Result<({EncryptedVault vault, BackupKey vaultKey}), SecretsFailure>>
      encryptVault({required Fingerprint seed}) async {
    try {
      return await _store.useAndForget(_key(seed), (bytes) async {
        final secret = SeedSecret.fromStorageBytes(bytes);
        final xprv = Bip32Derivation.xprvFromSeed(
            secret.seedBytes, Network.bitcoinMainnet);
        final path = Bip85Crypto.generateRecoverbullPath();
        final keyHex = Bip85Crypto.deriveBackupKeyHex(xprv, path);
        final keyBytes = Uint8List.fromList(conv.hex.decode(keyHex));

        final backup = rb.RecoverBull.createBackup(
          secret: secret.toStorageBytes(),
          backupKey: keyBytes,
        );
        return Ok((
          vault: EncryptedVault(backup.toJson()),
          vaultKey: BackupKey(keyBytes),
        ));
      });
    } on KeychainLockedException catch (e) {
      return Err(KeychainLockedFailure(sanitizeLog(e.toString())));
    } on SecretNotFoundException {
      return Err(SeedNotFoundFailure(seed));
    } on Exception catch (e) {
      return Err(VaultFailure(sanitizeLog(e.toString())));
    }
  }

  @override
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required BackupKey vaultKey,
  }) async {
    try {
      final backup = rb.BullBackup.fromJson(vault.ciphertextJson);
      final plaintext = rb.RecoverBull.restoreBackup(
        backup: backup,
        backupKey: vaultKey.bytes,
      );
      final secret =
          SeedSecret.fromStorageBytes(Uint8List.fromList(plaintext));

      final imported = switch (secret) {
        MnemonicSeedSecret(:final words, :final passphrase) =>
          await _repo.importMnemonic(words: words, passphrase: passphrase),
        BytesSeedSecret() => await _repo.importBytes(secret.seedBytes),
      };

      return switch (imported) {
        Ok(:final value) => Ok([value]),
        // A duplicate on restore is benign — the seed is already present.
        Err(failure: DuplicateSeedFailure(:final fingerprint)) =>
          Ok([fingerprint]),
        Err(:final failure) => Err(failure),
      };
    } on Exception catch (e) {
      return Err(VaultFailure(sanitizeLog(e.toString())));
    }
  }
}
