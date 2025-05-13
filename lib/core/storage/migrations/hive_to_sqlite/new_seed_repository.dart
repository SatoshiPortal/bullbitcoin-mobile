import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migration_secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new_seed_model.dart'
    show NewSeedModel;

class NewSecureStorageKeyPrefixConstants {
  static const seed = 'seed_';
}

class NewSeedRepository {
  final MigrationSecureStorageDatasource storageDatasource;

  NewSeedRepository(this.storageDatasource);

  Future<void> store({
    required String fingerprint,
    required NewSeedEntity seed,
  }) {
    final model = NewSeedModel.fromEntity(seed);
    final key = _seedKey(fingerprint);
    final value = json.encode(model.toJson());
    return storageDatasource.store(key: key, value: value);
  }

  String _seedKey(String fingerprint) =>
      '${NewSecureStorageKeyPrefixConstants.seed}$fingerprint';
}
