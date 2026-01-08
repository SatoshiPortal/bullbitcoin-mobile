import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/frameworks/secure_storage/fss_seed_secret_datasource.dart';
import 'package:bb_mobile/features/seeds/frameworks/secure_storage/seed_secret_model.dart';

class FssSeedSecretStore implements SeedSecretStorePort {
  final FssSeedSecretDatasource _seedSecretDatasource;

  const FssSeedSecretStore({
    required FssSeedSecretDatasource seedSecretDatasource,
  }) : _seedSecretDatasource = seedSecretDatasource;

  @override
  Future<void> save({
    required String fingerprint,
    required SeedSecret secret,
  }) async {
    return _seedSecretDatasource.store(
      fingerprint: fingerprint,
      seed: SeedSecretModel.fromSeedSecret(secret),
    );
  }

  @override
  Future<SeedSecret> load(String fingerprint) async {
    return _seedSecretDatasource
        .get(fingerprint)
        .then((model) => model!.toSeedSecret());
  }

  @override
  Future<bool> exists(String fingerprint) async {
    return _seedSecretDatasource.exists(fingerprint);
  }

  @override
  Future<List<SeedSecret>> listAll() async {
    final models = await _seedSecretDatasource.getAll();
    return models.map((model) => model.toSeedSecret()).toList();
  }

  @override
  Future<void> delete(String fingerprint) async {
    return _seedSecretDatasource.delete(fingerprint);
  }
}
