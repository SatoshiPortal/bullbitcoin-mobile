import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';

extension SecretUsageRowMappersX on SecretUsageRow {
  SecretUsage toDomain() {
    return SecretUsage(
      id: id,
      purpose: purpose,
      consumerRef: consumerRef,
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }
}

extension SecretUsageMappersX on SecretUsage {
  SecretUsageRow toRow() {
    return SecretUsageRow(
      id: id,
      purpose: purpose,
      consumerRef: consumerRef,
      fingerprint: fingerprint,
      createdAt: createdAt,
    );
  }
}
