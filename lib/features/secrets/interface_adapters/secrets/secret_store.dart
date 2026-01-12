import 'package:bb_mobile/core/primitives/secrets/secret.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_mappers.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_datasource.dart';

class SecretStore implements SecretStorePort {
  final SecretDatasource _secretDatasource;

  const SecretStore({required SecretDatasource secretDatasource})
    : _secretDatasource = secretDatasource;

  @override
  Future<void> save({
    required String fingerprint,
    required Secret secret,
  }) async {
    return _secretDatasource.store(
      fingerprint: fingerprint,
      secret: secret.toModel(),
    );
  }

  @override
  Future<Secret> load(String fingerprint) async {
    return _secretDatasource
        .get(fingerprint)
        .then((model) => model!.toDomain());
  }

  @override
  Future<bool> exists(String fingerprint) async {
    return _secretDatasource.exists(fingerprint);
  }

  @override
  Future<List<Secret>> loadAll() async {
    final models = await _secretDatasource.getAll();
    return models.map((model) => model.toDomain()).toList();
  }

  @override
  Future<void> delete(String fingerprint) async {
    return _secretDatasource.delete(fingerprint);
  }
}
