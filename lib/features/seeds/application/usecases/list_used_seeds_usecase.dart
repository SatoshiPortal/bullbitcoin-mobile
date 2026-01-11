import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class ListUsedSeedsQuery {
  // Add query parameters if needed in the future. E.g., filtering by purpose.

  const ListUsedSeedsQuery();
}

class ListUsedSeedsResult {
  final List<String> fingerprints;

  const ListUsedSeedsResult({required this.fingerprints});
}

class ListUsedSeedsUseCase {
  final SeedUsageRepositoryPort _seedUsageRepository;

  ListUsedSeedsUseCase({required SeedUsageRepositoryPort seedUsageRepository})
    : _seedUsageRepository = seedUsageRepository;

  Future<ListUsedSeedsResult> execute(ListUsedSeedsQuery query) async {
    try {
      final seedUsages = await _seedUsageRepository.getAll();
      final usedSeedFingerprints = seedUsages
          .map((usage) => usage.fingerprint)
          .toList();
      return ListUsedSeedsResult(fingerprints: usedSeedFingerprints);
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToListUsedSeedsError(e);
    }
  }
}
