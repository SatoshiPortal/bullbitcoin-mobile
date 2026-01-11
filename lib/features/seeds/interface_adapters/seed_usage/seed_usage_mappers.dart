import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/seeds/domain/entities/seed_usage_entity.dart';

extension SeedUsageMappersX on SeedUsageRow {
  SeedUsage toDomain() {
    return SeedUsage(
      id: id,
      purpose: purpose,
      consumerRef: consumerRef,
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }
}

extension SeedUsageEntityMappersX on SeedUsage {
  SeedUsageRow toRow() {
    return SeedUsageRow(
      id: id,
      purpose: purpose,
      consumerRef: consumerRef,
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }
}
