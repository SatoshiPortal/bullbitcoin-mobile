import 'dart:typed_data';

import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/seed_bytes.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';

sealed class ImportSeedSecretCommand {
  final Uint8List bytes;

  const ImportSeedSecretCommand({required this.bytes});

  const factory ImportSeedSecretCommand.forWallet({
    required String walletId,
    required Uint8List bytes,
  }) = ImportSeedSecretForWalletCommand;

  const factory ImportSeedSecretCommand.forBip85({
    required String bip85Path,
    required Uint8List bytes,
  }) = ImportSeedSecretForBip85Command;
}

class ImportSeedSecretForWalletCommand extends ImportSeedSecretCommand {
  final String walletId;

  const ImportSeedSecretForWalletCommand({
    required this.walletId,
    required super.bytes,
  });
}

class ImportSeedSecretForBip85Command extends ImportSeedSecretCommand {
  final String bip85Path;

  const ImportSeedSecretForBip85Command({
    required this.bip85Path,
    required super.bytes,
  });
}

class ImportSeedSecretResult {
  final Fingerprint fingerprint;

  ImportSeedSecretResult({required this.fingerprint});
}

class ImportSeedSecretUseCase {
  final SecretStorePort _secretStore;
  final SecretCryptoPort _secretCrypto;
  final SecretUsageRepositoryPort _secretUsageRepository;

  ImportSeedSecretUseCase({
    required SecretStorePort secretStore,
    required SecretCryptoPort secretCrypto,
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretStore = secretStore,
       _secretCrypto = secretCrypto,
       _secretUsageRepository = secretUsageRepository;

  /// Returns the secret fingerprint identity.
  Future<ImportSeedSecretResult> execute(ImportSeedSecretCommand cmd) async {
    try {
      // Check the command inputs
      final consumer = switch (cmd) {
        ImportSeedSecretForWalletCommand c => WalletConsumer(c.walletId),
        ImportSeedSecretForBip85Command c => Bip85Consumer(c.bip85Path),
      };
      final seedBytes = SeedBytes(cmd.bytes);

      // Derive fingerprint to identify the secret
      final fingerprint = await _secretCrypto.getFingerprintFromSeedBytes(
        seedBytes,
      );

      // First create the secret to store with validated value object
      final secret = SeedSecret(fingerprint: fingerprint, bytes: seedBytes);

      // Make sure the secret is successfully stored first before marking usage
      await _secretStore.save(secret);

      // Track usage
      await _secretUsageRepository.add(
        fingerprint: fingerprint,
        consumer: consumer,
      );

      return ImportSeedSecretResult(fingerprint: fingerprint);
    } on InvalidSeedBytesLengthError catch (e) {
      throw InvalidSeedInputError(e.actualLength);
    } on SecretsDomainError catch (e) {
      // Unexpected domain errors (e.g., InvalidFingerprintFormatError)
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToImportSeedSecretError(e);
    }
  }
}
