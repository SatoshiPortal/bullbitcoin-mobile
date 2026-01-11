import 'package:bb_mobile/features/seeds/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class LoadLegacySeedsQuery {
  const LoadLegacySeedsQuery();
}

class LoadLegacySeedsResult {
  final Map<String, SeedSecret> secretsByFingerprint;

  const LoadLegacySeedsResult({required this.secretsByFingerprint});
}

class LoadLegacySeedsUseCase {
  final LegacySeedSecretStorePort _legacySeedSecretStore;
  final SeedCryptoPort _seedCrypto;

  LoadLegacySeedsUseCase({
    required LegacySeedSecretStorePort legacySeedSecretStore,
    required SeedCryptoPort seedCrypto,
  }) : _legacySeedSecretStore = legacySeedSecretStore,
       _seedCrypto = seedCrypto;

  Future<LoadLegacySeedsResult> execute(LoadLegacySeedsQuery query) async {
    try {
      final secrets = await _legacySeedSecretStore.loadAll();
      Map<String, SeedSecret> secretsByFingerprint = {};
      for (final secret in secrets) {
        final fingerprint = await _seedCrypto.getFingerprintFromSeedSecret(
          secret,
        );
        secretsByFingerprint[fingerprint] = secret;
      }

      return LoadLegacySeedsResult(secretsByFingerprint: secretsByFingerprint);
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToLoadLegacySeedsError(e);
    }
  }
}
