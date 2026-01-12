import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/application/secrets_application_errors.dart';
import 'package:bb_mobile/features/secrets/application/usecases/deregister_secret_usage_usecase.dart';
import 'package:bb_mobile/features/secrets/application/usecases/get_secret_usage_by_consumer_usecase.dart';

class DeregisterSecretUsageWithFingerprintCheckCommand {
  final String fingerprint;
  final SecretUsagePurpose purpose;
  final String consumerRef;

  const DeregisterSecretUsageWithFingerprintCheckCommand({
    required this.fingerprint,
    required this.purpose,
    required this.consumerRef,
  });
}

/// Composed use case that validates fingerprint before deregistering a secret usage.
/// This ensures the secret being deregistered matches the expected fingerprint.
class DeregisterSecretUsageWithFingerprintCheckUseCase {
  final GetSecretUsageByConsumerUseCase _getSecretUsageByConsumer;
  final DeregisterSecretUsageUseCase _deregisterSecretUsage;

  DeregisterSecretUsageWithFingerprintCheckUseCase({
    required GetSecretUsageByConsumerUseCase getSecretUsageByConsumer,
    required DeregisterSecretUsageUseCase deregisterSecretUsage,
  }) : _getSecretUsageByConsumer = getSecretUsageByConsumer,
       _deregisterSecretUsage = deregisterSecretUsage;

  Future<void> execute(
    DeregisterSecretUsageWithFingerprintCheckCommand command,
  ) async {
    // Get the usage by consumer
    final result = await _getSecretUsageByConsumer.execute(
      GetSecretUsageByConsumerQuery(
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      ),
    );

    // Validate fingerprint matches
    if (result.usage.fingerprint != command.fingerprint) {
      throw FingerprintMismatchError(
        secretUsageId: result.usage.id,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );
    }

    // Deregister the usage
    await _deregisterSecretUsage.execute(
      DeregisterSecretUsageCommand(secretUsageId: result.usage.id),
    );
  }
}
