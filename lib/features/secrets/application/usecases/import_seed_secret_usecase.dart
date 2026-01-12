import 'dart:typed_data';

import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class ImportSeedSecretCommand {
  Uint8List bytes;
  SecretUsagePurpose purpose;
  String consumerRef;

  ImportSeedSecretCommand({
    required this.bytes,
    required this.purpose,
    required this.consumerRef,
  });
}

class ImportSeedSecretResult {
  final String fingerprint;

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
  Future<ImportSeedSecretResult> execute(
    ImportSeedSecretCommand command,
  ) async {
    try {
      // First create the secret to store
      final secret = SeedSecret(command.bytes);

      final fingerprint = await _secretCrypto.getFingerprintFromSecret(secret);

      // Make sure the secret is successfully stored first before marking usage
      await _secretStore.save(fingerprint: fingerprint, secret: secret);

      // Track usage
      await _secretUsageRepository.add(
        fingerprint: fingerprint,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );

      return ImportSeedSecretResult(fingerprint: fingerprint);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToImportSeedSecretError(e);
    }
  }
}
