import 'package:bb_mobile/core/primitives/seeds/seed_secret.dart';
import 'package:bb_mobile/features/seeds/application/ports/seed_secret_store_port.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_mappers.dart';
import 'package:bb_mobile/features/seeds/interface_adapters/seed_secrets/seed_secret_datasource.dart';

class SeedSecretStore implements SeedSecretStorePort {
  final SeedSecretDatasource _seedSecretDatasource;

  const SeedSecretStore({required SeedSecretDatasource seedSecretDatasource})
    : _seedSecretDatasource = seedSecretDatasource;

  @override
  Future<void> save({
    required String fingerprint,
    required SeedSecret secret,
  }) async {
    return _seedSecretDatasource.store(
      fingerprint: fingerprint,
      seed: secret.toModel(),
    );
  }

  @override
  Future<SeedSecret> load(String fingerprint) async {
    return _seedSecretDatasource
        .get(fingerprint)
        .then((model) => model!.toDomain());
  }

  @override
  Future<bool> exists(String fingerprint) async {
    return _seedSecretDatasource.exists(fingerprint);
  }

  @override
  Future<List<SeedSecret>> loadAll() async {
    final models = await _seedSecretDatasource.getAll();
    return models.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> delete(String fingerprint) async {
    return _seedSecretDatasource.delete(fingerprint);
  }
}
