import 'package:bb_mobile/core/primitives/seeds/seed_usage_purpose.dart';
import 'package:meta/meta.dart';

@immutable
class SeedUsage {
  final String id;
  final String fingerprint;
  final SeedUsagePurpose purpose;
  final String consumerRef; // e.g. wallet id, bip85 id, nostr public key, etc.
  final DateTime createdAt;

  const SeedUsage({
    required this.id,
    required this.fingerprint,
    required this.purpose,
    required this.consumerRef,
    required this.createdAt,
  });
}
