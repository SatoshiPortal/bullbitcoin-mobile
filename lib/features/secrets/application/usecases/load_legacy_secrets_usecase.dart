import 'package:bb_mobile/features/secrets/application/ports/legacy_seed_secret_store_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';

class LoadLegacySecretsQuery {
  const LoadLegacySecretsQuery();
}

class LoadLegacySecretsResult {
  final List<Secret> secrets;

  const LoadLegacySecretsResult({required this.secrets});
}

class LoadLegacySecretsUseCase {
  final LegacySecretStorePort _legacySecretStore;

  LoadLegacySecretsUseCase({required LegacySecretStorePort legacySecretStore})
    : _legacySecretStore = legacySecretStore;

  Future<LoadLegacySecretsResult> execute(LoadLegacySecretsQuery query) async {
    try {
      final secrets = await _legacySecretStore.loadAll();

      return LoadLegacySecretsResult(secrets: secrets);
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
