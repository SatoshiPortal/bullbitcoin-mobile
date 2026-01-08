import 'dart:typed_data';

import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';

class ImportSeedBytesCommand {
  Uint8List seedBytes;
  SeedUsagePurpose purpose;
  String consumerRef;

  ImportSeedBytesCommand({
    required this.seedBytes,
    required this.purpose,
    required this.consumerRef,
  });
}

class ImportSeedBytesResult {
  final String fingerprint;

  ImportSeedBytesResult({required this.fingerprint});
}

class ImportSeedBytesUseCase {
  final SeedSecretStorePort _seedSecretStore;
  final SeedCryptoPort _seedCrypto;
  final SeedUsageRepositoryPort _seedUsageRepository;

  ImportSeedBytesUseCase({
    required SeedSecretStorePort seedSecretStore,
    required SeedCryptoPort seedCrypto,
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedSecretStore = seedSecretStore,
       _seedCrypto = seedCrypto,
       _seedUsageRepository = seedUsageRepository;

  /// Returns the seed fingerprint identity.
  Future<ImportSeedBytesResult> execute(ImportSeedBytesCommand command) async {
    // First create the secret to store
    final seedSecret = SeedBytesSecret(command.seedBytes);

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

    return ImportSeedBytesResult(fingerprint: fingerprint);
  }
}
