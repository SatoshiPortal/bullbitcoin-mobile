import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_consumer.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/secret_usage_id.dart';
import 'package:meta/meta.dart';

@immutable
class SecretUsage {
  final SecretUsageId id;
  final Fingerprint fingerprint;
  final SecretConsumer consumer;
  final DateTime createdAt;

  const SecretUsage({
    required this.id,
    required this.fingerprint,
    required this.consumer,
    required this.createdAt,
  });
}
