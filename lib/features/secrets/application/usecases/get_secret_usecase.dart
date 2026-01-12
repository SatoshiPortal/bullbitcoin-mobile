import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

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
    try {
      final secret = await _secretStore.load(query.fingerprint);

      return GetSecretResult(secret: secret);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSecretError(query.fingerprint, e);
    }
  }
}
