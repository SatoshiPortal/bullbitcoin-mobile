import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';

abstract interface class SeedUsageRepositoryPort {
  Future<SeedUsage> add({
    required String fingerprint,
    required SeedUsagePurpose purpose,
    required String consumerRef,
  });
  Future<bool> isUsed(String fingerprint);
  Future<SeedUsage?> getByConsumer({
    required SeedUsagePurpose purpose,
    required String consumerRef,
  });
  Future<List<SeedUsage>> getAll();
  Future<void> deleteById(int id);
}
