import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

class ImportSeedMnemonicCommand {
  List<String> mnemonicWords;
  String? passphrase;
  SeedUsagePurpose purpose;
  String consumerRef;

  ImportSeedMnemonicCommand({
    required this.mnemonicWords,
    this.passphrase,
    required this.purpose,
    required this.consumerRef,
  });
}

class ImportSeedMnemonicResult {
  final String fingerprint;

  ImportSeedMnemonicResult({required this.fingerprint});
}

class ImportSeedMnemonicUseCase {
  final SeedSecretStorePort _seedSecretStore;
  final SeedCryptoPort _seedCrypto;
  final SeedUsageRepositoryPort _seedUsageRepository;

  ImportSeedMnemonicUseCase({
    required SeedSecretStorePort seedSecretStore,
    required SeedCryptoPort seedCrypto,
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedSecretStore = seedSecretStore,
       _seedCrypto = seedCrypto,
       _seedUsageRepository = seedUsageRepository;

  /// Returns the seed fingerprint identity.
  Future<ImportSeedMnemonicResult> execute(
    ImportSeedMnemonicCommand command,
  ) async {
    // First create the secret to store
    final seedSecret = SeedMnemonicSecret(
      words: command.mnemonicWords,
      passphrase: command.passphrase,
    );

    final fingerprint = await _seedCrypto.getFingerprintFromSeedSecret(
      seedSecret,
    );

    // Make sure the seed is successfully stored first before marking usage
    await _seedSecretStore.save(fingerprint: fingerprint, secret: seedSecret);

    // Track usage
    await _seedUsageRepository.add(
      fingerprint: fingerprint,
      purpose: command.purpose,
      consumerRef: command.consumerRef,
    );

    return ImportSeedMnemonicResult(fingerprint: fingerprint);
  }
}
