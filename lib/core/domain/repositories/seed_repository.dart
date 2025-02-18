import 'package:bb_mobile/core/domain/entities/seed.dart';

abstract class SeedRepository {
  Future<void> storeSeed(Seed seed);
  Future<Seed> getSeed(String fingerprint);
  Future<bool> hasSeed(String fingerprint);
  Future<void> deleteSeed(String fingerprint);
}
