import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

import '../ports/secret_store_port.dart';
import '../ports/secret_usage_repository_port.dart';

class DeleteSecretCommand {
  final String fingerprint;

  DeleteSecretCommand({required this.fingerprint});
}

class DeleteSecretUseCase {
  final SecretStorePort _secretStore;
  final SecretUsageRepositoryPort _secretUsageRepository;

  DeleteSecretUseCase({
    required SecretStorePort secretStore,
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretStore = secretStore,
       _secretUsageRepository = secretUsageRepository;

  Future<void> execute(DeleteSecretCommand cmd) async {
    try {
      // Check the cmd inputs
      final fingerprint = Fingerprint.fromHex(cmd.fingerprint);

      // Check if the secret is in use
      final isSecretUsed = await _secretUsageRepository.isUsed(fingerprint);

      if (isSecretUsed) {
        throw SecretInUseError(cmd.fingerprint);
      }

      await _secretStore.delete(fingerprint);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToDeleteSecretError(cmd.fingerprint, e);
    }
  }
}
