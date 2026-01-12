import 'package:bb_mobile/features/secrets/application/ports/secret_crypto_port.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class LoadAllStoredSecretsQuery {
  // final SeedSecretKind kind;

  const LoadAllStoredSecretsQuery();
}

class LoadAllStoredSecretsResult {
  final Map<String, Secret> secretsByFingerprint;

  const LoadAllStoredSecretsResult({required this.secretsByFingerprint});
}

class LoadAllStoredSecretsUseCase {
  final SecretStorePort _secretStore;
  final SecretCryptoPort _secretCrypto;

  LoadAllStoredSecretsUseCase({
    required SecretStorePort secretStore,
    required SecretCryptoPort secretCrypto,
  }) : _secretStore = secretStore,
       _secretCrypto = secretCrypto;

  Future<LoadAllStoredSecretsResult> execute(
    LoadAllStoredSecretsQuery query,
  ) async {
    try {
      final secrets = await _secretStore.loadAll();
      Map<String, Secret> secretsByFingerprint = {};
      for (final secret in secrets) {
        final fingerprint = await _secretCrypto.getFingerprintFromSecret(
          secret,
        );
        secretsByFingerprint[fingerprint] = secret;
      }

      return LoadAllStoredSecretsResult(
        secretsByFingerprint: secretsByFingerprint,
      );
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToLoadAllStoredSecretsError(e);
    }
  }
}
