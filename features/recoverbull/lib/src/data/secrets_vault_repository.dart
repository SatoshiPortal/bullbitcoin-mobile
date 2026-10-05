import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:secrets/secrets.dart' as custody;

import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_backup.dart';
import '../domain/entities/vault_context.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/vault_repository.dart';
import 'mappers/encrypted_vault_mapper.dart';

final class SecretsVaultRepository implements VaultRepository {
  final custody.Secrets _secrets;

  const SecretsVaultRepository(this._secrets);

  @override
  Result<EncryptedVault, RecoverBullFailure> parse(String document) {
    try {
      return Ok(EncryptedVaultMapper.parse(document));
    } on Exception {
      return const Err(VaultInvalidFailure());
    } on ArgumentError {
      // Entity validation is the boundary for an untrusted file's fields.
      return const Err(VaultInvalidFailure());
    }
  }

  @override
  String encode(EncryptedVault vault) =>
      EncryptedVaultMapper.fromEntity(vault).toFile();

  @override
  Future<Result<VaultBackup, RecoverBullFailure>> create(
    VaultContext context,
  ) async {
    final custody.Secret secret;
    switch (await _secrets.fetch(context.fingerprint)) {
      case Err(:final failure):
        return Err(_failure(failure));
      case Ok(:final value):
        secret = value;
    }
    if (!secret.info.isMnemonic || secret.info.hasPassphrase) {
      return const Err(VaultUnsupportedSecretFailure());
    }
    final result = await secret.backup.recoverbull(
      metadata: {
        'masterFingerprint': context.fingerprint.hex,
        'isEncryptedVaultTested': false,
        'latestEncryptedBackup': null,
      },
    );
    return switch (result) {
      Err(:final failure) => Err(_failure(failure)),
      Ok(:final value) => parse(value.vault.json).map((vault) {
        log.fine('recoverbull vault sealed');
        return VaultBackup(vault: vault, key: value.key, context: context);
      }),
    };
  }

  @override
  Future<Result<custody.VaultKey, RecoverBullFailure>> deriveKey(
    EncryptedVault vault,
  ) async {
    final List<custody.SecretEntry> entries;
    switch (await _secrets.list()) {
      case Ok(:final value):
        entries = value;
      case Err():
        return const Err(VaultSeedUnavailableFailure());
    }
    var unavailable = entries.any((entry) => entry is custody.UnreadableSecret);
    var attempted = false;
    for (final secret in entries.whereType<custody.Secret>()) {
      if (!secret.info.isMnemonic) continue;
      attempted = true;
      switch (await secret.backup.recoverbullKey(
        vault: custody.EncryptedVault(json: encode(vault)),
      )) {
        case Ok(:final value):
          return Ok(value);
        case Err(failure: custody.InvalidVaultPathFailure()):
          return const Err(VaultKeyPathUnavailableFailure());
        case Err(failure: custody.InvalidVaultFailure()):
          continue;
        case Err():
          unavailable = true;
      }
    }
    return unavailable || !attempted
        ? const Err(VaultSeedUnavailableFailure())
        : const Err(VaultLocalKeyMismatchFailure());
  }

  @override
  Future<Result<Fingerprint, RecoverBullFailure>> fingerprint(
    EncryptedVault vault,
    custody.VaultKey key,
  ) async =>
      (await _secrets.recoverbull.fingerprint(
            vault: custody.EncryptedVault(json: encode(vault)),
            key: key,
          ))
          .map((fingerprint) {
            log.fine('recoverbull vault inspected');
            return fingerprint;
          })
          .mapErr(_failure);

  @override
  Future<Result<Fingerprint, RecoverBullFailure>> restore(
    EncryptedVault vault,
    custody.VaultKey key,
  ) async =>
      (await _secrets.recoverbull.restore(
            vault: custody.EncryptedVault(json: encode(vault)),
            key: key,
          ))
          .map((restored) {
            log.fine('recoverbull vault imported');
            return restored.secret.id;
          })
          .mapErr(_failure);

  static RecoverBullFailure _failure(custody.SecretFailure failure) =>
      switch (failure) {
        custody.KeystoreLockedFailure() => const VaultKeystoreLockedFailure(),
        custody.SecretNotFoundFailure() => const VaultSecretMissingFailure(),
        custody.FetchSecretFailure() ||
        custody.StoreSecretFailure() => const VaultStorageFailure(),
        custody.InvalidVaultFailure() => const VaultInvalidFailure(),
        custody.MnemonicRequiredFailure() ||
        custody.PassphraseUnsupportedFailure() =>
          const VaultUnsupportedSecretFailure(),
        _ => const RecoverBullUnexpectedFailure(),
      };
}
