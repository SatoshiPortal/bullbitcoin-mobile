import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class CreateNewSeedMnemonicCommand {
  String? passphrase;
  SeedUsagePurpose purpose;
  String consumerRef;

  CreateNewSeedMnemonicCommand({
    this.passphrase,
    required this.purpose,
    required this.consumerRef,
  });
}

class CreateNewSeedMnemonicResult {
  final String fingerprint;
  final SeedSecret secret;

  const CreateNewSeedMnemonicResult({
    required this.fingerprint,
    required this.secret,
  });
}

class CreateNewSeedMnemonicUseCase {
  final MnemonicGeneratorPort _mnemonicGenerator;
  final SeedCryptoPort _seedCrypto;
  final SeedSecretStorePort _seedSecretStore;
  final SeedUsageRepositoryPort _seedUsageRepository;

  CreateNewSeedMnemonicUseCase({
    required MnemonicGeneratorPort mnemonicGenerator,
    required SeedCryptoPort seedCrypto,
    required SeedSecretStorePort seedSecretStore,
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _mnemonicGenerator = mnemonicGenerator,
       _seedCrypto = seedCrypto,
       _seedSecretStore = seedSecretStore,
       _seedUsageRepository = seedUsageRepository;

  Future<CreateNewSeedMnemonicResult> execute(
    CreateNewSeedMnemonicCommand command,
  ) async {
    try {
      // Generate a new mnemonic
      final mnemonicWords = await _mnemonicGenerator.generateMnemonic();

      // Create the seed secret from the mnemonic (and optional passphrase)
      final seedSecret = SeedMnemonicSecret(
        words: mnemonicWords,
        passphrase: command.passphrase,
      );

      // Calculate the fingerprint to identify the seed
      final fingerprint = await _seedCrypto.getFingerprintFromSeedSecret(
        seedSecret,
      );

      // Store the seed secret securely by its fingerprint
      await _seedSecretStore.save(fingerprint: fingerprint, secret: seedSecret);

      // Track the usage of the seed
      await _seedUsageRepository.add(
        fingerprint: fingerprint,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );

      return CreateNewSeedMnemonicResult(
        fingerprint: fingerprint,
        secret: seedSecret,
      );
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToCreateNewSeedMnemonicError(e);
    }
  }
}
