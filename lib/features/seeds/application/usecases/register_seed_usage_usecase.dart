import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class RegisterSeedUsageCommand {
  final String fingerprint;
  final SeedUsagePurpose purpose;
  final String consumerRef;

  const RegisterSeedUsageCommand({
    required this.fingerprint,
    required this.purpose,
    required this.consumerRef,
  });
}

class RegisterSeedUsageUseCase {
  final SeedUsageRepositoryPort _seedUsageRepository;

  RegisterSeedUsageUseCase({
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedUsageRepository = seedUsageRepository;

  Future<void> execute(RegisterSeedUsageCommand command) {
    try {
      return _seedUsageRepository.add(
        fingerprint: command.fingerprint,
        purpose: command.purpose,
        consumerRef: command.consumerRef,
      );
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToRegisterSeedUsageError(command.fingerprint, e);
    }
  }
}
