import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_error.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_error.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';

class ListUsedSecretsQuery {
  // Add query parameters if needed in the future. E.g., filtering by consumer.

  const ListUsedSecretsQuery();
}

class ListUsedSecretsResult {
  final List<Fingerprint> fingerprints;

  const ListUsedSecretsResult({required this.fingerprints});
}

class ListUsedSecretsUseCase {
  final SecretUsageRepositoryPort _secretUsageRepository;

  ListUsedSecretsUseCase({
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretUsageRepository = secretUsageRepository;

  Future<ListUsedSecretsResult> execute(ListUsedSecretsQuery query) async {
    try {
      final usages = await _secretUsageRepository.getAll();
      final usedSecretFingerprints = usages
          .map((usage) => usage.fingerprint)
          .toList();
      return ListUsedSecretsResult(fingerprints: usedSecretFingerprints);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToListUsedSecretsError(e);
    }
  }
}
