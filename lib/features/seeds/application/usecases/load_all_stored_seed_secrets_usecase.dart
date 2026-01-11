import 'package:bb_mobile/features/seeds/application/ports/seed_crypto_port.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class LoadAllStoredSeedSecretsQuery {
  // final SeedSecretKind kind;

  const LoadAllStoredSeedSecretsQuery();
}

class LoadAllStoredSeedSecretsResult {
  final Map<String, SeedSecret> secretsByFingerprint;

  const LoadAllStoredSeedSecretsResult({required this.secretsByFingerprint});
}

class LoadAllStoredSeedSecretsUseCase {
  final SeedSecretStorePort _seedSecretStore;
  final SeedCryptoPort _seedCrypto;

  LoadAllStoredSeedSecretsUseCase({
    required SeedSecretStorePort seedSecretStore,
    required SeedCryptoPort seedCrypto,
  }) : _seedSecretStore = seedSecretStore,
       _seedCrypto = seedCrypto;

  Future<LoadAllStoredSeedSecretsResult> execute(
    LoadAllStoredSeedSecretsQuery query,
  ) async {
    try {
      final secrets = await _seedSecretStore.loadAll();
      Map<String, SeedSecret> secretsByFingerprint = {};
      for (final secret in secrets) {
        final fingerprint = await _seedCrypto.getFingerprintFromSeedSecret(
          secret,
        );
        secretsByFingerprint[fingerprint] = secret;
      }

      return LoadAllStoredSeedSecretsResult(
        secretsByFingerprint: secretsByFingerprint,
      );
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToLoadAllStoredSeedSecretsError(e);
    }
  }
}
