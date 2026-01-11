import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_usage_repository_port.dart';
import 'package:bb_mobile/features/seeds/application/seeds_application_errors.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';
import 'package:bb_mobile/features/seeds/domain/seeds_domain_errors.dart';

class GetSeedUsageByConsumerQuery {
  final SeedUsagePurpose purpose;
  final String consumerRef;

  const GetSeedUsageByConsumerQuery({
    required this.purpose,
    required this.consumerRef,
  });
}

class GetSeedUsageByConsumerResult {
  final SeedUsage usage;

  GetSeedUsageByConsumerResult({required this.usage});
}

class GetSeedUsageByConsumerUseCase {
  final SeedUsageRepositoryPort _seedUsageRepository;

  GetSeedUsageByConsumerUseCase({
    required SeedUsageRepositoryPort seedUsageRepository,
  }) : _seedUsageRepository = seedUsageRepository;

  Future<GetSeedUsageByConsumerResult> execute(
    GetSeedUsageByConsumerQuery query,
  ) async {
    try {
      final usage = await _seedUsageRepository.getByConsumer(
        purpose: query.purpose,
        consumerRef: query.consumerRef,
      );

      if (usage == null) {
        throw SeedUsageNotFoundError(
          purpose: query.purpose,
          consumerRef: query.consumerRef,
        );
      }

      return GetSeedUsageByConsumerResult(usage: usage);
    } on SeedsDomainError catch (e) {
      // Map domain errors to application errors
      // For now just wrap all in a generic business rule failed
      throw BusinessRuleFailed(e);
    } on SeedsApplicationError {
      rethrow;
    } catch (e) {
      throw FailedToGetSeedUsageByConsumerError(
        purpose: query.purpose,
        consumerRef: query.consumerRef,
        cause: e,
      );
    }
  }
}
