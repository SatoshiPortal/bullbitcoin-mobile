import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_usage_repository_port.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/secrets_domain_errors.dart';

class GetSecretUsageByConsumerQuery {
  final SecretUsagePurpose purpose;
  final String consumerRef;

  const GetSecretUsageByConsumerQuery({
    required this.purpose,
    required this.consumerRef,
  });
}

class GetSecretUsageByConsumerResult {
  final SecretUsage usage;

  GetSecretUsageByConsumerResult({required this.usage});
}

class GetSecretUsageByConsumerUseCase {
  final SecretUsageRepositoryPort _secretUsageRepository;

  GetSecretUsageByConsumerUseCase({
    required SecretUsageRepositoryPort secretUsageRepository,
  }) : _secretUsageRepository = secretUsageRepository;

  Future<GetSecretUsageByConsumerResult> execute(
    GetSecretUsageByConsumerQuery query,
  ) async {
    try {
      final usage = await _secretUsageRepository.getByConsumer(
        purpose: query.purpose,
        consumerRef: query.consumerRef,
      );

      if (usage == null) {
        throw SecretUsageNotFoundError(
          purpose: query.purpose,
          consumerRef: query.consumerRef,
        );
      }

      return GetSecretUsageByConsumerResult(usage: usage);
    } on SecretsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SecretsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSecretUsageByConsumerError(
        purpose: query.purpose,
        consumerRef: query.consumerRef,
        cause: e,
      );
    }
  }
}
