import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/entities/new_seed_entity.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/new/models/new_seed_model.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/secure_storage_datasource.dart';

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

  Future<NewSeedEntity> fetch({required String fingerprint}) async {
    final key = _seedKey(fingerprint);
    final value = await storageDatasource.fetch(key: key);
    if (value == null) throw Exception('No seed found');
    final model = NewSeedModel.fromJson(
      json.decode(value) as Map<String, dynamic>,
    );
    return model.toEntity();
  }

  String _seedKey(String fingerprint) =>
      '${NewSecureStorageKeyPrefixConstants.seed}$fingerprint';
}
