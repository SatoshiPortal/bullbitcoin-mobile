import 'dart:convert';

import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/migration_secure_storage_datasource.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_seed.dart';

class OldSeedRepository {
  final MigrationSecureStorageDatasource storageDatasource;

  OldSeedRepository(this.storageDatasource);

  Future<OldSeed> fetch({required String fingerprint}) async {
    final jsn = await storageDatasource.fetch(key: fingerprint);
    if (jsn == null) throw Exception('No seed found');
    final obj = json.decode(jsn) as Map<String, dynamic>;
    final seed = OldSeed.fromJson(obj);
    seed.mnemonicFingerprint;
    return seed;
  }
}
