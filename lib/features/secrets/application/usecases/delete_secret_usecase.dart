import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

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

  Future<void> execute(DeleteSecretCommand command) async {
    try {
      final isSecretUsed = await _secretUsageRepository.isUsed(
        command.fingerprint,
      );

      if (isSecretUsed) {
        throw SecretInUseError(command.fingerprint);
      }

      await _secretStore.delete(command.fingerprint);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToDeleteSecretError(command.fingerprint, e);
    }
  }
}
