import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

import '../ports/seed_secret_store_port.dart';
import '../ports/seed_usage_repository_port.dart';

class DeleteSeedCommand {
  final String fingerprint;

  DeleteSeedCommand({required this.fingerprint});
}

class DeleteSeedUseCase {
  final SeedSecretStorePort _seedSecretStore;
  final SeedUsageRepositoryPort _seedUsageRepository;

  DeleteSeedUseCase({
    required SeedSecretStorePort seedSecretStore,
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedSecretStore = seedSecretStore,
       _seedUsageRepository = seedUsageRepository;

  Future<void> execute(DeleteSeedCommand command) async {
    try {
      final isSeedUsed = await _seedUsageRepository.isUsed(command.fingerprint);

      if (isSeedUsed) {
        throw SeedInUseError(command.fingerprint);
      }

      await _seedSecretStore.delete(command.fingerprint);
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToDeleteSeedError(command.fingerprint, e);
    }
  }
}
