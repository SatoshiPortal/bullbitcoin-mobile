import 'package:bb_mobile/features/secrets/domain/entities/secret_entity.dart';
import 'package:bb_mobile/features/secrets/application/ports/secret_store_port.dart';
import 'package:bb_mobile/features/secrets/domain/value_objects/fingerprint.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_mappers.dart';
import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_datasource.dart';

class SecretStore implements SecretStorePort {
  final SecretDatasource _secretDatasource;

  const SecretStore({required SecretDatasource secretDatasource})
    : _secretDatasource = secretDatasource;

  @override
  Future<void> save(Secret secret) async {
    return _secretDatasource.store(
      fingerprint: secret.fingerprint.value,
      secret: secret.toModel(),
    );
  }

  @override
  Future<Secret> load(Fingerprint fingerprint) async {
    return _secretDatasource
        .get(fingerprint.value)
        .then((model) => model!.toDomain(fingerprint.value));
  }

  @override
  Future<bool> exists(Fingerprint fingerprint) async {
    return _secretDatasource.exists(fingerprint.value);
  }

  @override
  Future<List<Secret>> loadAll() async {
    final secretsByFingerprint = await _secretDatasource.getAll();
    return secretsByFingerprint.entries
        .map((entry) => entry.value.toDomain(entry.key))
        .toList();
  }

  @override
  Future<void> delete(Fingerprint fingerprint) async {
    return _secretDatasource.delete(fingerprint.value);
  }
}
