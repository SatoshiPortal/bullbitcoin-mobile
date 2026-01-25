import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';

class LoadAllStoredSecretsQuery {
  const LoadAllStoredSecretsQuery();
}

class LoadAllStoredSecretsResult {
  final List<Secret> secrets;

  const LoadAllStoredSecretsResult({required this.secrets});
}

class LoadAllStoredSecretsUseCase {
  final SecretStorePort _secretStore;

  LoadAllStoredSecretsUseCase({required SecretStorePort secretStore})
    : _secretStore = secretStore;

  Future<LoadAllStoredSecretsResult> execute(
    LoadAllStoredSecretsQuery query,
  ) async {
    try {
      final secrets = await _secretStore.loadAll();

      return LoadAllStoredSecretsResult(secrets: secrets);
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
