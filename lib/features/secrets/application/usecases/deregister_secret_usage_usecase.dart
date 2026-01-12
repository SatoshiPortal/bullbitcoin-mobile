import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class DeregisterSecretUsageCommand {
  final int secretUsageId;

  const DeregisterSecretUsageCommand({required this.secretUsageId});
}

class DeregisterSecretUsageUseCase {
  final SecretUsageRepositoryPort _secretUsageRepository;

  DeregisterSecretUsageUseCase({
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretUsageRepository = secretUsageRepository;

  Future<void> execute(DeregisterSecretUsageCommand command) async {
    try {
      await _secretUsageRepository.deleteById(command.secretUsageId);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToDeregisterSecretUsageError(command.secretUsageId, e);
    }
  }
}
