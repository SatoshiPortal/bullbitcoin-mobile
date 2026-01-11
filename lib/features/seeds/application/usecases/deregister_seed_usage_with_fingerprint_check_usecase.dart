import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/application/usecases/deregister_seed_usage_usecase.dart';
import 'package:bb_mobile/features/seeds/application/usecases/get_seed_usage_by_consumer_usecase.dart';

class DeregisterSeedUsageWithFingerprintCheckCommand {
  final String fingerprint;
  final SeedUsagePurpose purpose;
  final String consumerRef;

  const DeregisterSeedUsageWithFingerprintCheckCommand({
    required this.fingerprint,
    required this.purpose,
    required this.consumerRef,
  });
}

/// Composed use case that validates fingerprint before deregistering a seed usage.
/// This ensures the seed being deregistered matches the expected fingerprint.
class DeregisterSeedUsageWithFingerprintCheckUseCase {
  final GetSeedUsageByConsumerUseCase _getSeedUsageByConsumer;
  final DeregisterSeedUsageUseCase _deregisterSeedUsage;

  DeregisterSeedUsageWithFingerprintCheckUseCase({
    required GetSeedUsageByConsumerUseCase getSeedUsageByConsumer,
    required DeregisterSeedUsageUseCase deregisterSeedUsage,
  }) : _getSeedUsageByConsumer = getSeedUsageByConsumer,
       _deregisterSeedUsage = deregisterSeedUsage;

  Future<void> execute(
    DeregisterSeedUsageWithFingerprintCheckCommand command,
  ) async {
    // Get the usage by consumer
    final result = await _getSeedUsageByConsumer.execute(
      GetSeedUsageByConsumerQuery(
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      ),
    );

    // Validate fingerprint matches
    if (result.usage.fingerprint != command.fingerprint) {
      throw FingerprintMismatchError(
        seedUsageId: result.usage.id,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );
    }

    // Deregister the usage
    await _deregisterSeedUsage.execute(
      DeregisterSeedUsageCommand(seedUsageId: result.usage.id),
    );
  }
}
