import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core_deprecated/storage/migrations/005_hive_to_sqlite/secure_storage_datasource.dart';

class OldSeedRepository {
  final MigrationSecureStorageDatasource storageDatasource;

  OldSeedRepository(this.storageDatasource);

  Future<OldSeed> fetch({required String fingerprint}) async {
    try {
      final seed = await storageDatasource.oldSeedFetch(fingerprint);
      return seed;
    } catch (e) {
      rethrow;
    }
  }
}
