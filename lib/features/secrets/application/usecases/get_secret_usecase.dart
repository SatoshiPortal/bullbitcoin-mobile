import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

class GetSecretQuery {
  final String fingerprint;

  const GetSecretQuery({required this.fingerprint});
}

class GetSecretResult {
  final Secret secret;

  const GetSecretResult({required this.secret});
}

class GetSecretUseCase {
  final SecretStorePort _secretStore;

  GetSecretUseCase({required SecretStorePort secretStore})
    : _secretStore = secretStore;

  Future<GetSecretResult> execute(GetSecretQuery query) async {
    Fingerprint? fingerprint;
    try {
      // Check the query inputs
      final fingerprint = Fingerprint(query.fingerprint);

      // Load the secret from the store
      final secret = await _secretStore.load(fingerprint);

      return GetSecretResult(secret: secret);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSecretError(fingerprint, e);
    }
  }
}
