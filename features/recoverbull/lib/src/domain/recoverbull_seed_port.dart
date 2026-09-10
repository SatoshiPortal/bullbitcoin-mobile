import 'entities/recoverbull_seed_material.dart';

abstract interface class RecoverBullSeedPort {
  Future<RecoverBullSeedMaterial> getSeed(String masterFingerprint);
}
