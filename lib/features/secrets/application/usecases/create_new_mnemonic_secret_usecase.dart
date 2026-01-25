import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/application/ports/mnemonic_generator_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';

sealed class CreateNewMnemonicSecretCommand {
  final String? passphrase;

  const CreateNewMnemonicSecretCommand({this.passphrase});

  const factory CreateNewMnemonicSecretCommand.forWallet({
    required String walletId,
    String? passphrase,
  }) = CreateNewMnemonicSecretForWalletCommand;

  const factory CreateNewMnemonicSecretCommand.forBip85({
    required String bip85Path,
    String? passphrase,
  }) = CreateNewMnemonicSecretForBip85Command;
}

class CreateNewMnemonicSecretForWalletCommand
    extends CreateNewMnemonicSecretCommand {
  final String walletId;

  const CreateNewMnemonicSecretForWalletCommand({
    required this.walletId,
    super.passphrase,
  });
}

class CreateNewMnemonicSecretForBip85Command
    extends CreateNewMnemonicSecretCommand {
  final String bip85Path;

  const CreateNewMnemonicSecretForBip85Command({
    required this.bip85Path,
    super.passphrase,
  });
}

class CreateNewMnemonicSecretResult {
  final MnemonicSecret secret;

  const CreateNewMnemonicSecretResult({required this.secret});
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
    CreateNewMnemonicSecretCommand cmd,
  ) async {
    try {
      // Check the cmd inputs
      final passphrase = cmd.passphrase != null
          ? Passphrase(cmd.passphrase!)
          : null;
      final consumer = switch (cmd) {
        CreateNewMnemonicSecretForWalletCommand c => WalletConsumer(c.walletId),
        CreateNewMnemonicSecretForBip85Command c => Bip85Consumer(c.bip85Path),
      };

      // Generate a new mnemonic
      final mnemonicWords = await _mnemonicGenerator.generateMnemonic();

      // Calculate the fingerprint to identify the seed
      final fingerprint = await _secretCrypto.getFingerprintFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      // Create the seed secret from the mnemonic (and optional passphrase) with validated value objects
      final secret = MnemonicSecret(
        fingerprint: fingerprint,
        words: mnemonicWords,
        passphrase: passphrase,
      );

      // Store the seed secret securely
      await _secretStore.save(secret);

      // Track the usage of the seed
      await _secretUsageRepository.add(
        fingerprint: fingerprint,
        consumer: consumer,
      );

      return CreateNewMnemonicSecretResult(secret: secret);
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
