import 'package:bb_mobile/core/primitives/secrets/secret_usage_purpose.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';

abstract interface class SecretUsageRepositoryPort {
  Future<SecretUsage> add({
    required String fingerprint,
    required SecretUsagePurpose purpose,
    required String consumerRef,
  });
  Future<bool> isUsed(String fingerprint);
  Future<SecretUsage?> getByConsumer({
    required SecretUsagePurpose purpose,
    required String consumerRef,
  });
  Future<List<SecretUsage>> getAll();
  Future<void> deleteById(int id);
}
