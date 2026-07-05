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
        // its buffer with a copy, so read it once here. Zero the plaintext
        // storage buffer afterwards (even on the createBackup throw path),
        // matching the package's buffer-hygiene standard.
        final secret = m.toStorageBytes();
        try {
          final backup = rb.RecoverBull.createBackup(
            secret: secret,
            backupKey: vaultKey.bytes,
          );
          return Ok(EncryptedVault(backup.toJson()));
        } finally {
          secret.fillRange(0, secret.length, 0);
        }
      }, onError: VaultFailure.new);

  @override
  Future<Result<List<Fingerprint>, SecretsFailure>> restoreVault({
    required EncryptedVault vault,
    required VaultKey vaultKey,
  }) =>
      _guard.run(() async {
        final backup = rb.BullBackup.fromJson(vault.ciphertextJson);
        final plaintext = Uint8List.fromList(rb.RecoverBull.restoreBackup(
          backup: backup,
          backupKey: vaultKey.bytes,
        ));
        // Zero the decrypted plaintext once we've parsed it (even on a
        // fromStorageBytes/import throw), matching the package hygiene standard.
        try {
          final mnemonic = Mnemonic.fromStorageBytes(plaintext);

          // Map the decoded language to the package enum. A null here means the
          // stored blob names a language this package does not mirror — defaulting
          // to English would re-derive a DIFFERENT seed (wrong wordlist) under a
          // mismatched fingerprint, the exact silent-guessing the storage decoder
          // forbids. Fail closed instead. (Dead today — the decoder only ever
          // yields a mirrored language — but the guess-vs-fail decision is pinned.)
          final language = MnemonicLanguage.fromName(mnemonic.language.name);
          if (language == null) {
            return const Err(VaultFailure(
                'restored mnemonic uses an unsupported language — refusing to '
                'guess the wordlist'));
          }

          final imported = await _repo.importMnemonic(
            words: mnemonic.words,
            passphrase: mnemonic.passphrase,
            language: language,
          );

          return switch (imported) {
            Ok(:final value) => Ok([value]),
            // A duplicate on restore is benign — the seed is already present.
            Err(failure: DuplicateSecretFailure(:final fingerprint)) =>
              Ok([fingerprint]),
            Err(:final failure) => Err(failure),
          };
        } finally {
          plaintext.fillRange(0, plaintext.length, 0);
        }
      }, onError: VaultFailure.new);
}
