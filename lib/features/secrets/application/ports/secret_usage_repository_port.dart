import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/entities/secret_usage_entity.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';

abstract interface class SecretUsageRepositoryPort {
  Future<SecretUsage> add({
    required Fingerprint fingerprint,
    required SecretConsumer consumer,
  });
  Future<bool> isUsed(Fingerprint fingerprint);
  Future<List<SecretUsage>> getAll();
  Future<List<SecretUsage>> getByConsumer(SecretConsumer consumer);
  Future<void> deleteById(SecretUsageId id);
  Future<void> deleteByConsumer(SecretConsumer consumer);
}
