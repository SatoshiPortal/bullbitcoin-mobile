import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/old/entities/old_seed.dart';
import 'package:bb_mobile/core/storage/migrations/hive_to_sqlite/secure_storage_datasource.dart';

class OldSeedRepository {
  final MigrationSecureStorageDatasource storageDatasource;

  OldSeedRepository(this.storageDatasource);

  Future<OldSeed> fetch({required String fingerprint}) async {
    final seed = await storageDatasource.oldSeedFetch(fingerprint);
    return seed;
  }
}
