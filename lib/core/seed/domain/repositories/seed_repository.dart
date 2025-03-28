import 'package:bb_mobile/core/seed/domain/entity/seed.dart';

abstract class SeedRepository {
  Future<void> store({
    required String fingerprint,
    required Seed seed,
  });
  Future<Seed> get(String fingerprint);
  Future<bool> exists(String fingerprint);
  Future<void> delete(String fingerprint);
}
