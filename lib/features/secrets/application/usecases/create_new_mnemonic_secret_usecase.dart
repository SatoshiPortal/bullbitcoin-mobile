import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class CreateNewMnemonicSecretCommand {
  String? passphrase;
  SecretUsagePurpose purpose;
  String consumerRef;

  CreateNewMnemonicSecretCommand({
    this.passphrase,
    required this.purpose,
    required this.consumerRef,
  });
}

class CreateNewMnemonicSecretResult {
  final String fingerprint;
  final MnemonicSecret secret;

  const CreateNewMnemonicSecretResult({
    required this.fingerprint,
    required this.secret,
  });
}

class CreateNewMnemonicSecretUseCase {
  final MnemonicGeneratorPort _mnemonicGenerator;
  final SecretCryptoPort _secretCrypto;
  final SecretStorePort _secretStore;
  final SecretUsageRepositoryPort _secretUsageRepository;

  CreateNewMnemonicSecretUseCase({
    required MnemonicGeneratorPort mnemonicGenerator,
    required SecretCryptoPort secretCrypto,
    required SecretStorePort secretStore,
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _mnemonicGenerator = mnemonicGenerator,
       _secretCrypto = secretCrypto,
       _secretStore = secretStore,
       _secretUsageRepository = secretUsageRepository;

  Future<CreateNewMnemonicSecretResult> execute(
    CreateNewMnemonicSecretCommand command,
  ) async {
    try {
      // Generate a new mnemonic
      final mnemonicWords = await _mnemonicGenerator.generateMnemonic();

      // Create the seed secret from the mnemonic (and optional passphrase)
      final secret = MnemonicSecret(
        words: mnemonicWords,
        passphrase: command.passphrase,
      );

      // Calculate the fingerprint to identify the seed
      final fingerprint = await _secretCrypto.getFingerprintFromSecret(secret);

      // Store the seed secret securely by its fingerprint
      await _secretStore.save(fingerprint: fingerprint, secret: secret);

      // Track the usage of the seed
      await _secretUsageRepository.add(
        fingerprint: fingerprint,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );

      return CreateNewMnemonicSecretResult(
        fingerprint: fingerprint,
        secret: secret,
      );
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToCreateNewMnemonicSecretError(e);
    }
  }
}
