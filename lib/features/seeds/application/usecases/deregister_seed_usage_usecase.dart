import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';

class DeregisterSeedUsageCommand {
  final int seedUsageId;

  const DeregisterSeedUsageCommand({required this.seedUsageId});
}

class DeregisterSeedUsageUseCase {
  final SeedUsageRepositoryPort _seedUsageRepository;

  DeregisterSeedUsageUseCase({
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedUsageRepository = seedUsageRepository;

  Future<void> execute(DeregisterSeedUsageCommand command) async {
    try {
      await _seedUsageRepository.deleteById(command.seedUsageId);
    } catch (e) {
      throw FailedToDeregisterSeedUsageError(command.seedUsageId, e);
    }
  }
}
