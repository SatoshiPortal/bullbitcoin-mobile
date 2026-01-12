import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class LoadLegacySecretsQuery {
  const LoadLegacySecretsQuery();
}

class LoadLegacySecretsResult {
  final Map<String, Secret> secretsByFingerprint;

  const LoadLegacySecretsResult({required this.secretsByFingerprint});
}

class LoadLegacySecretsUseCase {
  final LegacySecretStorePort _legacySecretStore;
  final SecretCryptoPort _secretCrypto;

  LoadLegacySecretsUseCase({
    required LegacySecretStorePort legacySecretStore,
    required SecretCryptoPort secretCrypto,
  }) : _legacySecretStore = legacySecretStore,
       _secretCrypto = secretCrypto;

  Future<LoadLegacySecretsResult> execute(LoadLegacySecretsQuery query) async {
    try {
      final secrets = await _legacySecretStore.loadAll();
      Map<String, Secret> secretsByFingerprint = {};
      for (final secret in secrets) {
        final fingerprint = await _secretCrypto.getFingerprintFromSecret(
          secret,
        );
        secretsByFingerprint[fingerprint] = secret;
      }

      return LoadLegacySecretsResult(
        secretsByFingerprint: secretsByFingerprint,
      );
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToLoadLegacySecretsError(e);
    }
  }
}
