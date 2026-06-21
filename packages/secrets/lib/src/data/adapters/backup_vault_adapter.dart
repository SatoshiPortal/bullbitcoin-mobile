import 'dart:typed_data';

import 'package:convert/convert.dart' as conv;
import 'package:primitives/primitives.dart';
import 'package:recoverbull/recoverbull.dart' as rb;
import 'package:secrets/src/crypto/bip32_derivation.dart';
import 'package:secrets/src/crypto/bip85_derivation.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/models/mnemonic.dart';
import 'package:secrets/src/domain/ports/backup_vault_port.dart';
import 'package:secrets/src/domain/ports/secret_store_port.dart';
import 'package:secrets/src/domain/ports/seed_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';
import 'package:secrets/src/domain/value_objects/backup.dart';

/// Wraps the `recoverbull` package directly (NOT the app-layer JSON wrappers).
/// The vault plaintext is the mnemonic's storage representation, encrypted with
/// a fresh BIP85-derived backup key; restore re-imports through [SeedPort] so
/// the mnemonic never escapes.
class BackupVaultAdapter implements BackupVaultPort {
  BackupVaultAdapter({
    required SecretStorePort store,
    required SeedPort repository,
  })  : _guard = SecretGuard(store),
        _repo = repository;

  final SecretGuard _guard;
  final SeedPort _repo;

  SecretsFailure _err(String log) => VaultFailure(log);

  @override
  Future<Result<({EncryptedVault vault, BackupKey vaultKey}), SecretsFailure>>
      encryptVault({required Fingerprint seed}) =>
          _guard.read(seed, (m) async {
            final xprv = Bip32Derivation.xprvFromSeed(
                m.toSeed().bytes, Network.bitcoinMainnet);
            final path = Bip85Crypto.generateRecoverbullPath();
            final keyHex = Bip85Crypto.deriveBackupKeyHex(xprv, path);
            final keyBytes = Uint8List.fromList(conv.hex.decode(keyHex));

            final backup = rb.RecoverBull.createBackup(
              secret: m.toStorageBytes(),
              backupKey: keyBytes,
            );
            return Ok((
              vault: EncryptedVault(backup.toJson()),
              vaultKey: BackupKey(keyBytes),
            ));
          }, onError: _err);

  @override
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required BackupKey vaultKey,
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
          language: mnemonic.language.name,
        );

        return switch (imported) {
          Ok(:final value) => Ok([value]),
          // A duplicate on restore is benign — the seed is already present.
          Err(failure: DuplicateSeedFailure(:final fingerprint)) =>
            Ok([fingerprint]),
          Err(:final failure) => Err(failure),
        };
      }, onError: _err);
}
