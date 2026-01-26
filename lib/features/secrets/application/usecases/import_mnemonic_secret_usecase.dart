import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/mnemonic_words.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/passphrase.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';

sealed class ImportMnemonicSecretCommand {
  final List<String> mnemonicWords;
  final String? passphrase;

  const ImportMnemonicSecretCommand({
    required this.mnemonicWords,
    this.passphrase,
  });

  const factory ImportMnemonicSecretCommand.forWallet({
    required String walletId,
    required List<String> mnemonicWords,
    String? passphrase,
  }) = ImportMnemonicSecretForWalletCommand;

  const factory ImportMnemonicSecretCommand.forBip85({
    required String bip85Path,
    required List<String> mnemonicWords,
    String? passphrase,
  }) = ImportMnemonicSecretForBip85Command;
}

class ImportMnemonicSecretForWalletCommand extends ImportMnemonicSecretCommand {
  final String walletId;

  const ImportMnemonicSecretForWalletCommand({
    required this.walletId,
    required super.mnemonicWords,
    super.passphrase,
  });
}

class ImportMnemonicSecretForBip85Command extends ImportMnemonicSecretCommand {
  final String bip85Path;

  const ImportMnemonicSecretForBip85Command({
    required this.bip85Path,
    required super.mnemonicWords,
    super.passphrase,
  });
}

class ImportMnemonicSecretResult {
  final Fingerprint fingerprint;

  const ImportMnemonicSecretResult({required this.fingerprint});
}

class ImportMnemonicSecretUseCase {
  final SecretStorePort _secretStore;
  final SecretCryptoPort _secretCrypto;
  final SecretUsageRepositoryPort _secretUsageRepository;

  ImportMnemonicSecretUseCase({
    required SecretStorePort secretStore,
    required SecretCryptoPort secretCrypto,
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretStore = secretStore,
       _secretCrypto = secretCrypto,
       _secretUsageRepository = secretUsageRepository;

  /// Returns the secret fingerprint identity.
  Future<ImportMnemonicSecretResult> execute(
    ImportMnemonicSecretCommand command,
  ) async {
    try {
      // Check the command inputs
      final consumer = switch (command) {
        ImportMnemonicSecretForWalletCommand c => WalletConsumer(c.walletId),
        ImportMnemonicSecretForBip85Command c => Bip85Consumer(c.bip85Path),
      };

      final mnemonicWords = MnemonicWords(command.mnemonicWords);
      final passphrase = command.passphrase != null
          ? Passphrase(command.passphrase!)
          : null;

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

      // Make sure the secret is successfully stored first before marking usage
      await _secretStore.save(secret);

      // Track usage
      await _secretUsageRepository.add(
        fingerprint: fingerprint,
        consumer: consumer,
      );

      return ImportMnemonicSecretResult(fingerprint: fingerprint);
    } on InvalidMnemonicWordCountError catch (e) {
      throw InvalidMnemonicInputError(e.actualCount);
    } on InvalidPassphraseLengthError catch (e) {
      throw InvalidPassphraseInputError(e.actualLength);
    } on SecretsDomainError catch (e) {
      // Unexpected domain errors (e.g., InvalidFingerprintFormatError)
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToImportMnemonicSecretError(e);
    }
  }
}
