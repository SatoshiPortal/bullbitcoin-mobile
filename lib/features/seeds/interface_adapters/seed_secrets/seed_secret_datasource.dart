import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_model.dart';

abstract interface class SeedSecretDatasource {
  Future<void> store({
    required String fingerprint,
    required SeedSecretModel seed,
  });

  Future<SeedSecretModel?> get(String fingerprint);

  Future<bool> exists(String fingerprint);

  Future<List<SeedSecretModel>> getAll();

  Future<void> delete(String fingerprint);
}
